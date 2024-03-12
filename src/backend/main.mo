
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat32";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Sha256 "mo:sha2/Sha256";
import Hex "Hex";

import HttpTypes "http/http.types";
import SupdTypes "Types";
import Utils "Utils";

import ChainF "blockchain/ChainFactory";
import TokenF "blockchain/TokenFactory";
import CurrencyF "currency/FXFactory";
import PriceF "blockchain/PriceFactory";
import CheckoutFactory "checkout/CheckoutFactory";
import PaymentFactory "payments/PaymentFactory";
import TokenFactory "blockchain/TokenFactory";
shared ({caller = owner}) actor class Main() = this {

    private let FX_CACHE_TIME_SECONDS : Nat = 600;  //10 min cache    

    let IS_TEST_MODE : Bool = true;  //enables all test tokens and chains  
    
    private stable var mstore = Map.new<Text, SupdTypes.Merchant>();
    private stable var logStore = Map.new<Text, SupdTypes.CheckoutLog>();
    private stable var quoteStore = Map.new<Text, SupdTypes.TokenQuote>();
    private stable var currencyStore = Map.new<Text, SupdTypes.CurrencyQuote>();
    private stable var productStore = Map.new<Text, SupdTypes.Product>();
    private stable var paymentStore = Map.new<Text, SupdTypes.CheckoutPaymentSetting>();
    private stable var orderStore = Map.new<Text, SupdTypes.Order>();
    private stable var receiptStore = Map.new<Text, SupdTypes.OrderReceipt>();
   
    public query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    //TODO:  better way?
    public query func canisterId() : async Text {
        let p = Principal.fromActor(this);
        return Principal.toText(p);
    };   

    //to help https outcall reach consensus you strip the resulting headers
    public query func transform_response(raw : HttpTypes.TransformArgs) : async HttpTypes.HttpResponsePayload {
        let transformed : HttpTypes.HttpResponsePayload = {
            status = raw.response.status;
            body = raw.response.body;
            headers = [
                {
                    name = "Content-Security-Policy";
                    value = "default-src 'self'";
                },
                { name = "Referrer-Policy"; value = "strict-origin" },
                { name = "Permissions-Policy"; value = "geolocation=(self)" },
                {
                    name = "Strict-Transport-Security";
                    value = "max-age=63072000";
                },
                { name = "X-Frame-Options"; value = "DENY" },
                { name = "X-Content-Type-Options"; value = "nosniff" },
            ];
        };        
        return transformed;
    };    
  
    /* -------------------CHAINS----------------------- */
    //get chains supported
    public query func getChains() : async [SupdTypes.TokenChain] {
        let f = TokenF.TokenFactory(true);
        let c = f.getChains();
        return c;
    };

    /* -------------------TOKENS----------------------- */
    //get tokens supported
    public query func getTokens() : async [SupdTypes.Token] {
        let f = TokenF.TokenFactory(true);
        let t = f.getTokens();
        return t;
    };    

     //get tokens - serves from 1 min cache 
    public query func getTokensWithQuotes() : async [SupdTypes.Token] {        
        let f = TokenF.TokenFactory(true);
        let bootstrap = f.getTokens();        
        var result = List.nil<SupdTypes.Token>();
        for(token in bootstrap.vals()){
            let cached : ?SupdTypes.TokenQuote = getTokenQuoteCached(token.name);
            switch(cached){
                case null{
                    result := List.push(token, result);
                };
                case(?cached){
                     var clone : SupdTypes.Token = {
                        name = token.name;
                        token_type = token.token_type;
                        abi = token.abi;
                        contract = token.contract;
                        chains = token.chains;
                        created_at = token.created_at;
                        decimals = token.decimals;
                        last_quote = ?cached;
                        description = token.description;
                        slug = token.slug;
                    };         
                    result := List.push(clone, result);
                };
            };
        };
        //Debug.print("getTokensWithQuotes result: " # debug_show(result));
        return List.toArray(result);        
    };

    //get latest token quote via provider avg
    public func getTokenQuote(token : Text) : async ?SupdTypes.TokenQuote {        
        let cached = getTokenQuoteCached(token);        
        if(cached != null){
            return cached;
        };
        let tf = TokenF.TokenFactory(true);
        let match_or_trap = await tf.getToken(token);
        var main_actor_id = await canisterId();
        let factory : PriceF.PriceFactory = PriceF.PriceFactory(main_actor_id, #eth_mainnet, match_or_trap, true);
        let quote = await factory.getTokenQuote();        
        switch(quote){
            case null return null;
            case(?quote){
                let anon = Principal.fromText("2vxsx-fae");                
                logTokenQuote(anon, quote, "getTokenQuote testing"); //add to cache
                return ?quote;
            };
        };
    };

    //get top n token quotes ordered by date desc
    public query func getTokenQuoteHistory(token : Text, page_size : Nat) : async ?[SupdTypes.TokenQuote] {
        assert(Text.size(token) > 2);
        assert(page_size > 0 and page_size <= 100);
        let filter = Text.toUppercase(token);        
        let ok = Map.filterDesc(quoteStore, thash, func(k : Text, yo : SupdTypes.TokenQuote) : Bool {
            yo.name == filter;
        });
        let filteredQuoteHistory = Map.vals(ok);        
        let result : [SupdTypes.TokenQuote] = Iter.toArray(filteredQuoteHistory);
        let top10_result = List.take(List.fromArray(result), page_size);
        let a = List.toArray(top10_result);
        return ?a;
    };


    /* -------------------FX----------------------- */
    //get currencies supported - serves from 1 min cache 
    public shared query func getCurrencies() : async ?[SupdTypes.CurrencyQuote] {        
        let f = CurrencyF.CurrencyFactory("", true);
        let bootstrap = f.getFxBootstrap();
        var result = List.nil<SupdTypes.CurrencyQuote>();
        for(currency in bootstrap.vals()){            
            var cached : ?SupdTypes.CurrencyQuote = getQuoteCached(currency.name);            
            switch(cached){
                case null{
                    result := List.push(currency, result);
                };
                case(?cached){
                    result := List.push(cached, result);
                };
            };
        };
        return ?List.toArray(result);
    };

    //get fx quote with details - serves from 1 min cache
    public func getQuote(fx_symbol : Text) : async ?SupdTypes.CurrencyQuote {
        let cached = getQuoteCached(fx_symbol);        
        if(cached != null){
            return cached;
        };
        let this_canister_id = await canisterId(); //TODO:  optimize
        let factory = CurrencyF.CurrencyFactory(this_canister_id, true);
        let match = await factory.getCurrency(fx_symbol);
        let quote = await factory.getQuote(match);
        switch(quote){
            case null return null;
            case(?quote){
                let anon = Principal.fromText("2vxsx-fae");
                logPriceQuote(anon, quote, "getQuote testing");
                return ?quote;
            };
        };
    };

    //get count of fx quotes
    public query func getQuoteHistoryCount() : async Nat {        
        let count = Map.size(currencyStore);        
        return count;
    };

    //get top n fx quotes ordered by date desc
    public query func getQuoteHistory(fx_symbol : Text, page_size : Nat) : async ?[SupdTypes.CurrencyQuote] {
        assert(Text.size(fx_symbol) == 3);
        assert(page_size > 0 and page_size <= 100);
        let filter = Text.toUppercase(fx_symbol);        
        let ok = Map.filterDesc(currencyStore, thash, func(k : Text, yo : SupdTypes.CurrencyQuote) : Bool {
            yo.name == filter;
        });
        let filteredQuoteHistory = Map.vals(ok);
        let result : [SupdTypes.CurrencyQuote] = Iter.toArray(filteredQuoteHistory);
        let top10_result = List.take(List.fromArray(result), page_size);
        let a = List.toArray(top10_result);
        return ?a;
    };

    //get most recent fx quote ttl FX_CACHE_TIME_SECONDS 
    private func getQuoteCached(fx_symbol : Text) : ?SupdTypes.CurrencyQuote {
        assert(Text.size(fx_symbol) == 3);
        let filter = Text.toUppercase(fx_symbol);            
        let ok = Map.filterDesc(currencyStore, thash, func(k : Text, yo : SupdTypes.CurrencyQuote) : Bool {            
            Text.toUppercase(yo.name) == filter;
        });
        if(Map.size(ok) > 0){
            let most_recent = Iter.toArray(Map.vals(ok))[0];
            switch(?most_recent){
                case null return null;
                case(?most_recent){        
                    let now = Nat64.toNat(Utils.now_seconds());
                    let cached_ts = Nat64.toNat(most_recent.created_at);                    
                    let diff = Nat.sub(now, cached_ts);
                    //Debug.print("DIFFERENCE: " # debug_show(diff));
                    if(diff > FX_CACHE_TIME_SECONDS){                      
                        Debug.print("CACHE KEY: " # debug_show(filter));
                        return null;
                    };
                    //Debug.print("SERVING YOU FROM currencyStore CACHE for key: " # debug_show(filter));
                    return ?most_recent;
                };
            };
        };
        return null;
    };
    
    //get token with most recent price from cache FX_CACHE_TIME_SECONDS
    private func getTokenQuoteCached(token : Text) : ?SupdTypes.TokenQuote {        
        let filter = Text.toUppercase(token);            
        let ok = Map.filterDesc(quoteStore, thash, func(k : Text, yo : SupdTypes.TokenQuote) : Bool {            
            Text.toUppercase(yo.name) == filter;
        });
        if(Map.size(ok) > 0){
            let most_recent = Iter.toArray(Map.vals(ok))[0];
            switch(?most_recent){
                case null return null;
                case(?most_recent){        
                    let now = Nat64.toNat(Utils.now_seconds());
                    let cached_ts = Nat64.toNat(most_recent.created_at);                
                    let diff = Nat.sub(now, cached_ts);
                    if(diff > FX_CACHE_TIME_SECONDS){                                                
                        return null;
                    };
                    //Debug.print("SERVING YOU FROM quoteStore CACHE for key: " # debug_show(filter));
                    return ?most_recent;
                };
            };
        };
        return null;
    };

    //get merchant payment settings for view
    public query (context) func getPaymentSettings() : async ?[SupdTypes.PubSetting] {              
        var stuff = List.nil<SupdTypes.PubSetting>();
        let caller : Principal = context.caller;
        assert(Principal.isAnonymous(caller) != true);
        let mkey = merchantKey(Principal.toText(caller));
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return null;
            case (?merchant){
                var pf = PaymentFactory.PaymentFactory(merchant, paymentStore, logStore);
                var ps = pf.getPaymentSettings();
                let match = Array.filter<(Text, SupdTypes.CheckoutPaymentSetting)>(ps, func(x) = x.1.is_enabled == true);
                //Debug.print("match: " # debug_show(match));
                for((key, val) in match.vals()){                 
                    let p : SupdTypes.PubSetting = {
                        cid = val.cid;
                        guid = val.guid;
                        created_at = val.created_at;
                        updated_at = val.updated_at;
                        token_type = val.token_type;
                        chain = val.chain;
                        is_enabled = val.is_enabled;
                    };
                    stuff := List.push(p, stuff);
                };
                let ok = List.toArray(stuff);
                return ?ok;
            };
        };
    };

    //get merchant payment settings by token slug
    public shared (context) func getPaymentSetting(slug : Text) : async ?SupdTypes.CheckoutPaymentSetting {
        let caller : Principal = context.caller;
        assert(Principal.isAnonymous(caller) != true);
        let mkey = merchantKey(Principal.toText(caller));
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return null;
            case (?merchant){                
                var pf = PaymentFactory.PaymentFactory(merchant, paymentStore, logStore);
                var pt = await pf.getPaymentSettingBySlug(slug);
                return pt;
            };
        };
    };

    //update merchant payment setting instance
    public shared (context) func updatePaymentSetting(slug : Text, chain : Text, dest : Text, enabled : Bool) : async Bool {
        let caller : Principal = context.caller;
        assert(Principal.isAnonymous(caller) != true);
        let mkey = merchantKey(Principal.toText(caller));
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return false;
            case (?merchant){                
                var pf = PaymentFactory.PaymentFactory(merchant, paymentStore, logStore);
                let update_result = await pf.updatePaymentSetting(caller, slug, chain, dest, enabled);
                return update_result;
            };
        };
    };

    /* -------------------CHECKOUT----------------------- */
    //PUBLIC NO validation
    //get is_checkout enabled    
    public query func getCheckoutStatus(cid : Text) : async Bool {
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid
        });        
        switch(merchant){
            case null return false;
            case(?merchant){              
                return merchant.1.is_enabled;
            };
        };
    };

    //PUBLIC NO validation
    //get checkout store for view
    public query func getCheckoutStoreView(cid : Text) : async SupdTypes.Response<SupdTypes.CheckoutStoreView> {
        assert(Text.size(cid) == 64);
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid
        });        
        switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){                              
                let f = CheckoutFactory.CheckoutFactory("", merchant.1, productStore);
                let sv = f.getCheckoutStoreView();
                return {
                    status = 200;
                    status_text = "OK";
                    data = ?sv;
                    error_text = null;
                };
            };
        };        
    };

    //PUBLIC NO validation - not logged in II    
    public query func getCheckoutPaymentOptions(cid : Text, chain : Text) : async SupdTypes.Response<[SupdTypes.CheckoutPaymentSetting]>{
        let tf = TokenF.TokenFactory(true);        
        let chain_match = tf.chainFromTextOrTrap(chain);
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid
        });
        switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){
                var pf = PaymentFactory.PaymentFactory(merchant.1, paymentStore, logStore);
                var payment_options = pf.getPaymentsByChain(chain_match);
                if(Array.size(payment_options) == 0){
                    return {
                        status = 404;
                        status_text = "Error";
                        data = null;
                        error_text = ?"No payments for chain found";
                    };
                }else{
                    return {
                        status = 200;
                        status_text = "OK";
                        data = ?payment_options;
                        error_text = null;
                    };
                };
            };
        };        
    };        

    
    //PUBLIC NO validation - not logged in II    
    //TODO: :  rate limit somehow + client server nonce
    public shared (context) func createQuoteForCart(cid : Text, token : Text, chain : Text, cart : SupdTypes.ShoppingCart) : async SupdTypes.Response<?SupdTypes.CartQuoteResponse> {
        var tf = TokenFactory.TokenFactory(true);
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid
        });        
        switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){                             
                var main_actor_id = await canisterId();
                let cf = CheckoutFactory.CheckoutFactory(main_actor_id, merchant.1, productStore);
                let cached : ?SupdTypes.TokenQuote = await getTokenQuote(token); //potential FX_CACHE_TIME_SECONDS slippage but speeds up UI 3x
                let thing = await cf.createQuoteForCart(chain, token, cart, cached);                
                return {
                    status = 200;
                    status_text = "OK";
                    data = ?thing;
                    error_text = null;
                };
            };
        };        
    };

    /*------------ ORDERS ------------------ */
    //validate transaction  - business rules specific to site
    private func validateOrderRequest(merchant : SupdTypes.Merchant, cid: Text, token : Text, chain : Text, block_height : Text, tx_hash : Text, cart : SupdTypes.ShoppingCart, source_wallet : Text, dest_wallet : Text, amt : Float, gas : Text) : async Bool {
        var tf = TokenFactory.TokenFactory(true);
        var pf = PaymentFactory.PaymentFactory(merchant, paymentStore, logStore);
        
        var chain_match = tf.chainFromTextOrTrap(chain);
        var token_currency_match = await tf.getToken(token);
        var token_match = tf.locateTokenDetails(token_currency_match, chain_match);
        if(chain_match == #eth_mainnet){
            if(Text.size(tx_hash) < 66){
                return false;
            };
        };
        
        if(amt <= 0){
            return false;
        };

        //dest_wallet has to exist in payment
        var valid_dest = await pf.validateDestAddressExists(token_currency_match, chain_match, dest_wallet);
        if(valid_dest == false){
            Debug.print("validateOrderRequest WARNING ADDRESS DOES NOT EXIST " # debug_show(valid_dest));
            return false;
        };

        Debug.print("validateOrderRequest PASSED " # debug_show(tx_hash));
        return true;
    };


    //TODO: :  server side evm/chain check    
    //create an order for a hash
    public shared (context) func createOrder(cid: Text, token : Text, chain : Text, block_height: Text, tx_hash : Text, cart : SupdTypes.ShoppingCart, source_wallet : Text, dest_wallet : Text, amt : Float, gas : Text) : async SupdTypes.Response<SupdTypes.OrderReceipt> {         
        var tf = TokenFactory.TokenFactory(true);
        var chain_match = tf.chainFromTextOrTrap(chain);
        var token_currency_match = await tf.getToken(token);
        var token_match = await tf.locateTokenDetails(token_currency_match, chain_match);
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid and yo.is_enabled == true  //could cause valid transactions to get rejected if in mempool
            //yo.cid == cid
        });
        switch(merchant){
            case null {
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){
                var main_actor_id = await canisterId();
                let cf = CheckoutFactory.CheckoutFactory(main_actor_id, merchant.1, productStore);
                let cached : ?SupdTypes.TokenQuote = await getTokenQuote(token);
                if(cached == null){
                    return {
                        status = 404;
                        status_text = "Error";
                        data = null;
                        error_text = ?"Dry cache";
                    };
                };
                var order_totals = cf.calculateCartTotals(cart);
                if(order_totals.grand_total != amt){
                    Debug.print("ERROR order_totals and amt do not match!");
                    return {
                        status = 404;
                        status_text = "Error";
                        data = null;
                        error_text = ?"Order totals and amt do not match";
                    };
                };
                let is_merchant_enabled = merchant.1.is_enabled;
                let is_request_valid = await validateOrderRequest(merchant.1, cid, token, chain, block_height, tx_hash, cart, source_wallet, dest_wallet, amt, gas); //may trap TODO:  catch
                if(is_request_valid == false){
                    return {
                        status = 404;
                        status_text = "Error";
                        data = null;
                        error_text = ?"Failed validation";
                    };
                };                
                
                //TODO:  check existence of hash on chain
                //let bf = ChainF.ChainFactory(await Utils.randomProvider());
                
                let key = Text.toLowercase(tx_hash); //TODO:  same store for all orders so key needs to dupe check                
                let existing_receipt = Map.find(receiptStore, func(k : Text, yo : SupdTypes.OrderReceipt) : Bool {
                    //yo.cid == cid and yo.onchain_tx == tx_hash and yo.chain == chain_match
                     //yo.onchain_tx == tx_hash and yo.chain == chain_match
                     Text.toLowercase(yo.onchain_tx) == Text.toLowercase(tx_hash) //enforces global uniqueness 1 time use
                });
                if(existing_receipt != null){
                    return {
                        status = 404;
                        status_text = "Error";
                        data = null;
                        error_text = ?"Failed validation";
                    };
                };
                //Debug.print("existing_receipt passed ... creating order");
                let r_key = Utils.textToSha(cid # tx_hash);
                let order : SupdTypes.Order = {
                    cid = cid;
                    oid = key;  //TODO:  is this universally unique across chains? what happens on diff checkout/cids
                    foreign_key = ?"";
                    onchain_tx = tx_hash;
                    block_height = block_height;
                    chain = chain_match;
                    status = #processing; //TODO:  can edit?
                    created_at = Utils.now_seconds(); //TODO:  chain time
                    updated_at = Utils.now_seconds();
                    grand_total = order_totals.grand_total;
                    currency = #usd;
                };
                
                let inserted = Map.put(orderStore, thash, key, order);                
                logMerchant(context.caller, cid, 201, "ORDER INSERTED");

                var receipt = createReceiptView(r_key, order, cart, order_totals, token_match, gas);
                let receipt_added = Map.add(receiptStore, thash, r_key, receipt);                
                logMerchant(context.caller, cid, 201, "RECEIPT INSERTED");

                return {
                    status = 200;
                    status_text = "Success";
                    data = ?receipt;
                    error_text = ?"";
                };
            };
        };
    };

    private func createReceiptView(r_key : Text, order : SupdTypes.Order, cart : SupdTypes.ShoppingCart, cart_totals : SupdTypes.CartTotals, token : SupdTypes.Token, gas : Text) : SupdTypes.OrderReceipt {        

        var receipt : SupdTypes.OrderReceipt = {
            rid = r_key; 
            oid = order.oid;
            cid = order.cid;
            created_at = order.created_at;
            updated_at = order.updated_at;
            items = cart.items;
            sub_total = cart_totals.sub_total;
            tax_total = cart_totals.tax_total;
            shipping_total = cart_totals.shipping_total;
            total = cart_totals.grand_total;
            additional_fee = 0.00;
            discount = 0.00;
            gas = gas;            
            currency = order.currency;
            onchain_tx = order.onchain_tx;
            block_height = order.block_height;
            chain = order.chain;
            token_currency = token.token_type;
            token_slug = token.slug;

            //TODO:  not storing this information no shipping implementation
            source_wallet = "";
            dest_wallet = "";
            email = ?"";
            first_name= ?"";
            last_name= ?"";
            shipping_address1 = ?"";
            shipping_address2 = ?"";
            shipping_city = ?"";
            shipping_state = ?"";
            shipping_country = ?"";
            shipping_zip = ?"";
            shipping_phone = ?"";
            extra_data = ?[];
        };

        return receipt;
    };

    //get orders by checkout
    public query (context) func getOrders(cid : Text) : async ?[SupdTypes.Order] {
        let mkey = merchantKey(Principal.toText(context.caller));       
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return null;
            case(?merchant){               
                let ok = Map.filterDesc(orderStore, thash, func(k : Text, yo : SupdTypes.Order) : Bool {
                    yo.cid == cid;
                });
                var t = Map.vals(ok);
                return ?Iter.toArray(t);
            };
        };
    };

    //get receipts by checkout
    public query (context) func getReceipts(cid : Text) : async ?[SupdTypes.OrderReceipt] {
        let mkey = merchantKey(Principal.toText(context.caller));       
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return null;
            case(?merchant){               
                let ok = Map.filterDesc(receiptStore, thash, func(k : Text, yo : SupdTypes.OrderReceipt) : Bool {
                    yo.cid == cid;
                });
                var t = Map.vals(ok);
                return ?Iter.toArray(t);
            };
        };
    };

    //TODO:  security
    public query(context) func getReceipt(cid : Text, rid : Text) : async ?SupdTypes.OrderReceipt {
        let receipt = Map.find(receiptStore, func(k : Text, yo : SupdTypes.OrderReceipt) : Bool {
            yo.cid == cid and yo.rid == rid;
        });
        switch(receipt){
            case null return null;
            case(?receipt){              
                return ?receipt.1;
            };
        };        
    };


    //TODO:  security
    public query(context) func getReceiptByReceiptId(rid : Text) : async ?SupdTypes.PubOrderReceipt {
        let receipt = Map.find(receiptStore, func(k : Text, yo : SupdTypes.OrderReceipt) : Bool {
            yo.rid == rid;
        });
        switch(receipt){
            case null return null;
            case(?receipt){      
                var r : SupdTypes.OrderReceipt = receipt.1;
                var return_r : SupdTypes.PubOrderReceipt = {
                    rid = r.rid;
                    oid = r.oid;
                    cid = r.cid;
                    created_at = r.created_at;
                    updated_at = r.updated_at;

                    sub_total = r.sub_total;
                    tax_total = r.tax_total;
                    shipping_total = r.shipping_total;
                    total = r.total;
                    discount = r.discount;
                    gas = r.gas;
                    currency = r.currency;
                    additional_fee = r.additional_fee;

                    onchain_tx = r.onchain_tx;
                    block_height = r.block_height;
                    token_currency = r.token_currency;
                    token_slug = r.token_slug;                    
                    chain = r.chain;
                };
                return ?return_r;
            };
        };        
    };
   

    /* -------------------MERCHANT----------------------- */
    public query (context) func getMerchantId() : async Text{
        let caller : Principal = context.caller;
        assert(Principal.isAnonymous(caller) != true);
        let mkey = merchantKey(Principal.toText(caller));
        let merchant = Map.get(mstore, thash, mkey.key);     
        switch(merchant){
            case null{
                return "";
            };
            case(?merchant){
                return merchant.cid;
            };
        };
    };

    public query (context) func getMerchant() : async SupdTypes.Response<SupdTypes.Merchant> {
        let caller : Principal = context.caller;
        if(Principal.isAnonymous(caller)){
            return {
                status = 401;
                status_text = "Unauthorized";
                data = null;
                error_text = ?"Access denied - you must be logged in with an Internet Identity";
            };
        };

        let mkey = merchantKey(Principal.toText(caller));       
        let merchant = Map.get(mstore, thash, mkey.key);      
        switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Not Found";
                    data = null;                    
                    error_text = ?("Merchant not found.");
                };
            };
            case(?merchant){
                return {
                    status = 200;
                    status_text = "OK";
                    data = ?merchant;
                    error_text = null;
                };
            };
        };    
    };

    public shared (context) func updateMerchant(merchant : SupdTypes.Merchant) : async SupdTypes.Response<SupdTypes.Merchant> {
        let caller : Principal = context.caller;
        if(Principal.isAnonymous(caller)){
            return {
                status = 401;
                status_text = "Unauthorized";
                data = null;
                error_text = ?"Access denied - you must be logged in with an Internet Identity";
            };
        };

        let mkey = merchantKey(Principal.toText(caller)); //only 1 site per login
        var cid = merchant.cid;
        let existing = Map.get(mstore, thash, mkey.key);
        if(existing == null){
            let ent = Nat64.toText(Utils.now());
            cid := generateCheckoutId(caller, ent);
        };
        if(Text.size(cid) == 0){            
            return {
                status = 500;
                status_text = "Error";
                data = null;
                error_text = ?"There was an error updating the store";
            };
        };

        let upsert : SupdTypes.Merchant = {             
            cid = cid;
            name = merchant.name;
            is_enabled = merchant.is_enabled;
            created_at = merchant.created_at;
            updated_at = Utils.now_seconds(); 
            email_address = merchant.email_address;            
            phone_number = merchant.phone_number;
            phone_notifications = merchant.phone_notifications;
            email_notifications = merchant.email_notifications;            
        };

        let inserted = Map.put(mstore, thash, mkey.key, upsert);
        if(inserted == null){
            logMerchant(context.caller, cid, 201, "CHECKOUT INSERTED");
        }else{
            logMerchant(context.caller, cid, 200, "CHECKOUT UPDATED");
        };

        let latest = Map.get(mstore, thash, mkey.key);
        switch(latest){
            case null{      
                logMerchant(context.caller, cid, 500, "match ERROR NO MODEL FOUND");                     
                return {
                    status = 500;
                    status_text = "Error";
                    data = null;
                    error_text = ?"There was an error updating the model";
                };
            };
            case(?latest){
                return {
                    status = 200;
                    status_text = "OK";
                    data = ?latest;
                    error_text = null;
                };
            };
        };      
    }; 

    /* ---------- PRODUCTS ----------------------*/
    public query (context) func getMerchantProducts(cid : Text) : async SupdTypes.Response<[(Text, SupdTypes.Product)]> {        
        assert(Text.size(cid) == 64);
        if(Principal.isAnonymous(context.caller)){
            return {
                status = 401;
                status_text = "Unauthorized";
                data = null;
                error_text = ?"Access denied - you must be logged in with an Internet Identity";
            };
        };
        let merchant = Map.find(mstore, func(k : Text, yo : SupdTypes.Merchant) : Bool {
            yo.cid == cid
        });        
        switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){              
                let f = CheckoutFactory.CheckoutFactory("", merchant.1, productStore);
                let products = f.getProducts();
                return {
                    status = 200;
                    status_text = "OK";
                    data = ?products;
                    error_text = null;
                };
            };
        };
    };

    public shared (context) func getMerchantProduct(pid : Text) : async ?SupdTypes.Response<SupdTypes.Product> {
        assert(Text.size(pid) == 64);
        if(Principal.isAnonymous(context.caller)){
            return ?{
                status = 401;
                status_text = "Unauthorized";
                data = null;
                error_text = ?"Access denied - you must be logged in with an Internet Identity";
            };
        };
        let mkey = merchantKey(Principal.toText(context.caller));       
        let merchant = Map.get(mstore, thash, mkey.key);
        switch(merchant){
            case null return null;
            case(?merchant){
                let f = CheckoutFactory.CheckoutFactory("", merchant, productStore);
                let product = f.getProduct(pid);
                return ?
                {
                    status = 200;
                    status_text = "OK";
                    data = product;
                    error_text = null;
                };
            };
        };
    };    


    public shared (context) func updateMerchantProduct(cid : Text, product : SupdTypes.Product) : async SupdTypes.Response<SupdTypes.Product> {        
        let caller : Principal = context.caller;
        if(Principal.isAnonymous(caller)){
            return {
                status = 401;
                status_text = "Unauthorized";
                data = null;
                error_text = ?"Access denied - you must be logged in with an Internet Identity";
            };
        };        
        let mkey = merchantKey(Principal.toText(caller));
        let merchant = Map.get(mstore, thash, mkey.key);
         switch(merchant){
            case null{
                return {
                    status = 404;
                    status_text = "Error";
                    data = null;
                    error_text = ?"No merchant found";
                };
            };
            case(?merchant){                
                var pid = product.pid;                
                if(Text.size(pid) == 0 or pid == "0" or pid == "undefined"){
                    let k = merchant.cid # Principal.toText(caller) # product.sku # product.description; //TODO:  dedupe products by sku?
                    let sha = Utils.textToSha(k);
                    pid := sha;
                };
                let upsert : SupdTypes.Product = {                    
                    pid = pid;
                    cid = merchant.cid;                    
                    is_enabled = product.is_enabled;
                    foreign_key = product.foreign_key;
                    created_at = product.created_at;
                    updated_at = Utils.now_seconds();
                    name = product.name;
                    sku = product.sku;
                    price = product.price;
                    description = product.description;
                    description2 = product.description2;
                    tax1rate = product.tax1rate;
                    tax2rate = product.tax2rate;
                    image_url = product.image_url;
                    tags = ?[];
                    tax_mode = product.tax_mode;
                };

                let cf = CheckoutFactory.CheckoutFactory("", merchant, productStore);
                let is_valid = cf.validateProduct(upsert);
                if(is_valid == false){
                    return {
                        status = 500;
                        status_text = "Error";
                        data = null;
                        error_text = ?"Product validation failed";
                    };
                };
                
                let pkey = merchantKey(pid);
                let inserted = Map.put(productStore, thash, pkey.key, upsert);
                if(inserted == null){
                    logMerchant(context.caller, cid, 201, "PRODUCT INSERTED");
                }else{
                    logMerchant(context.caller, cid, 200, "PRODUCT UPDATED");
                };

                let latest = Map.get(productStore, thash, pkey.key);
                switch(latest){
                    case null{
                        logMerchant(context.caller, cid, 500, "match ERROR NO PRODUCT FOUND");
                        return {
                            status = 500;
                            status_text = "Error";
                            data = null;
                            error_text = ?"There was an error updating the product";
                        };
                    };
                    case(?latest){
                        return {
                            status = 200;
                            status_text = "OK";
                            data = ?latest;
                            error_text = null;
                        };
                    };
                };                
            };
        };      
    };
    

   
    /* -------------------LOGGING / CACHING----------------------- */
    public query (context) func getMerchantLogs(cid : Text) : async [SupdTypes.CheckoutLog] {
        if(Principal.isAnonymous(context.caller)){
            return [];
        };
        let ok = Map.filterDesc(logStore, thash, func(k : Text, yo : SupdTypes.CheckoutLog) : Bool {
            yo.cid == cid and yo.owner == Principal.toText(context.caller);
        });
        var m = Map.vals(ok);
        return Iter.toArray(m);        
    };

    private func logMerchant(caller : Principal, cid : Text, status_code : Nat16, log_msg : Text) {        
        let time_now = Utils.now_seconds();
        let p = Principal.toText(caller);
        var l : SupdTypes.CheckoutLog = {
            cid = cid;
            status = status_code;
            status_text = log_msg;
            owner = p;
            created_at = time_now;
        };
        let f = p # cid # Nat64.toText(time_now) # log_msg;
        let sha = Utils.textToSha(f);
        let ok = Map.put(logStore, thash, sha, l);
        return;
    };

    private func logPriceQuote(caller: Principal, quote : SupdTypes.CurrencyQuote, log_msg : Text) {        
        let time_now = Utils.now_seconds();
        let p = Principal.toText(caller);
        var l : SupdTypes.CurrencyQuote = {
            name = quote.name;
            symbol = quote.symbol;
            value = quote.value;
            value_str = quote.value_str;
            created_at = time_now;
            source = quote.source;
            currency_type = quote.currency_type;
            description = quote.description;
        };        
        let f = p # Nat64.toText(quote.created_at) # log_msg;
        let sha = Utils.textToSha(f);
        let ok = Map.put(currencyStore, thash, sha, l);
        Debug.print("I logged a PRICE quote " # debug_show(l));
        return;
    };    

    private func logTokenQuote(caller: Principal, quote : SupdTypes.TokenQuote, log_msg : Text) {      
        let time_now = Utils.now_seconds();
        let p = Principal.toText(caller);
        var l : SupdTypes.TokenQuote = {
            name = quote.name;
            symbol = quote.symbol;
            value = quote.value;
            value_str = quote.value_str;
            created_at = time_now;
            source = quote.source;
            token_type = quote.token_type;
            currency_type = #usd;
        };
        let f = p # Nat64.toText(time_now) # log_msg;
        let sha = Utils.textToSha(f);
        let ok = Map.put(quoteStore, thash, sha, l);
        Debug.print("I logged a TOKEN quote " # debug_show(l));
        return;
    };  

    /* ------------------- UTILS ----------------------- */
    //TODO:  review security 
    private func generateCheckoutId(p : Principal, ent : Text) : Text {
        if(Principal.isAnonymous(p)){            
            return "";
        };
        assert(ent.size() > 10);
        let t = Principal.toText(p);
        let n = Nat64.toText(Utils.now());
        let f = t # n # ent;

        let x = Blob.toArray(Text.encodeUtf8(f));
        let sha = Sha256.fromArray(#sha256, x);
        
        let hash = Hex.encode(Blob.toArray(sha));        
        return hash;
    };

    private func merchantKey(x : Text) : Trie.Key<Text> {
        return { hash = Text.hash(x); key = x };
    }; 

    private func merchantProductKey(x : Text) : Trie.Key<Text> {
        return { hash = Text.hash(x); key = x };
    };
    
};

