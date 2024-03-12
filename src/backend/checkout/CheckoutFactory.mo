
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
import Float "mo:base/Float";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Sha256 "mo:sha2/Sha256";
import Hex "../Hex";
import HttpTypes "../http/http.types";
import SupdTypes "../Types";
import Utils "../Utils";
import TokenFactory "../blockchain/TokenFactory";
import PriceFactory "../blockchain/PriceFactory";

//General class to help with product management and checkout
module CheckoutFactory {
    
    public class CheckoutFactory(calling_actor : Text, merchant : SupdTypes.Merchant, pStore : Map.Map<Text, SupdTypes.Product>){

        private let main_actor_id = calling_actor;      //todo can be moved out 

        public let MAX_PRODUCT_PRICE : Float = 1000.00; //max individual item cart price
        public let MIN_PRODUCT_PRICE : Float = 0.10;
        
        private let checkout_id : Text = merchant.cid;
        private let this_merchant : SupdTypes.Merchant = merchant;
        private let productStore : Map.Map<Text, SupdTypes.Product> = pStore;

        private func productKey(x : Text) : Trie.Key<Text> {
            return { hash = Text.hash(x); key = x }
        };
      
        //add a new product validation rules
        public func validateProduct(product : SupdTypes.Product) : Bool {
            if(product.price <= MIN_PRODUCT_PRICE or product.price > MAX_PRODUCT_PRICE){
                return false;
            };
            if(Text.size(product.sku) < 3 or Text.size(product.sku) > 100){
                return false;
            };
            if(Text.size(product.description) < 3 or Text.size(product.description) > 500){
                return false;
            };

            // if(product.tax_mode == #exclusive){
            //     if(product.tax1rate < 0 or product.tax1rate > 0.20){
            //         return false;
            //     };                
            // }else{
            //     //no taxes but they defined some
            //     if(product.tax1rate > 0 or product.tax2rate > 0){
            //         return false;
            //     };
            // };

            // if(1 == 2){ //allow products with same sku?
            //     var exists = getProductBySku(product.sku);
            // };

            return true;
        };

        
        public func getProducts() : [(Text, SupdTypes.Product)] {            
            let ok = Map.filterDesc(productStore, thash, func(k : Text, yo : SupdTypes.Product) : Bool {
                yo.cid == checkout_id;
            });
            return Map.toArray(ok);
        };

        public func getProduct(pid : Text) : ?SupdTypes.Product {            
            let ok = Map.find(productStore, func(k : Text, yo : SupdTypes.Product) : Bool {
                yo.cid == checkout_id and yo.pid == pid;
            });
            switch(ok){
                case null return null;
                case(?ok){
                    return ?ok.1;
                };
            };
        };

        public func getProductBySku(sku : Text) : ?SupdTypes.Product {
            let matchsku = Text.toUppercase(sku);
            let ok = Map.find(productStore, func(k : Text, yo : SupdTypes.Product) : Bool {
                yo.cid == checkout_id and Text.toUppercase(yo.sku) == matchsku;
            });
            switch(ok){
                case null return null;
                case(?ok){
                    return ?ok.1;
                };
            };
        };        

        public func getCheckoutStoreView() : SupdTypes.CheckoutStoreView {
            let ok = Map.filter(productStore, thash, func(k : Text, yo : SupdTypes.Product) : Bool {
                yo.cid == checkout_id;
            });
            let products = Iter.toArray(Map.vals(ok));
            let clone : SupdTypes.Merchant = {
                cid = this_merchant.cid;
                name = this_merchant.name;
                created_at = this_merchant.created_at;
                updated_at = this_merchant.updated_at;
                is_enabled = this_merchant.is_enabled;
                email_address = "";
                email_notifications = this_merchant.email_notifications;
                phone_number = "";
                phone_notifications = this_merchant.phone_notifications;
            };
            let sv : SupdTypes.CheckoutStoreView = {
                created_at = Utils.now_seconds();
                merchant = clone;
                products = ?products;
                chains = null;
            };
            return sv;
        };
        
        private func calculateTokenDenomination(units_per_token : Float, decimals : Int) : Text {            
            let multiple = Float.pow(10, Float.fromInt(decimals));
            let result = Float.mul(units_per_token, multiple);            
            return Int.toText(Float.toInt(result)); //amt in wei
        };
     
        public func calculateCartTotals(cart : SupdTypes.ShoppingCart) : SupdTypes.CartTotals {
            var grand_total = 0.00;
            var sub_total = 0.00;
            var tax_total = 0.00;
            var taxes = List.nil<Float>();
            for(item in cart.items.vals()){
                var line = Float.fromInt(item.qty) * item.price;
                var tax_line_multiplier = item.tax1rate + item.tax2rate;
                if(tax_line_multiplier > 0){
                    var thing = tax_line_multiplier * line;
                    taxes := List.push(thing, taxes);
                };
                sub_total += line;
            };

            if(cart.shipping_total > 0){
                sub_total += cart.shipping_total;
            };
            
            for(this_tax in List.toArray<Float>(taxes).vals()){                
                tax_total := Float.add(tax_total, this_tax);                
            };
            
            grand_total := sub_total + tax_total;
            //Debug.print("the subtotal for cart is: " # debug_show(sub_total));
            //Debug.print("the grand total for cart is: " # debug_show(grand_total));
            var totals : SupdTypes.CartTotals = {
                shipping_total = cart.shipping_total;
                additional_fee = 0.0;
                sub_total = sub_total;
                tax_total = tax_total;
                grand_total = grand_total;
                discount = 0;
            };

            return totals;
        };

        //for a given cart and token, calculate the total value of the cart in the token
        public func createQuoteForCart(chain : Text, token : Text, cart : SupdTypes.ShoppingCart, recent_quote : ?SupdTypes.TokenQuote) : async ?SupdTypes.CartQuoteResponse {                        
            assert(Text.size(chain) > 5);
            assert(Text.size(token) > 2);
            let tf = TokenFactory.TokenFactory(true);
            let token_currency = await tf.getToken(token);
            let chain_match = tf.chainFromText(chain);
            switch(chain_match){
                case null return null;
                case(?chain_match){                    
                    let pf = PriceFactory.PriceFactory(main_actor_id, chain_match, token_currency, true);
                    let token_details = await tf.locateTokenDetails(token_currency, chain_match);
                    var latest_quote : ?SupdTypes.TokenQuote = null;
                    if(recent_quote != null){
                        latest_quote := recent_quote;
                    }else{
                        latest_quote := await pf.getTokenQuote(); //~6 seconds
                    };                    
                    switch(latest_quote){
                        case null return null;
                        case(?latest_quote){
                            
                            var cart_totals = calculateCartTotals(cart);                            
                            var grand_total = cart_totals.grand_total;
                            var sub_total = cart_totals.sub_total;
                            var tax_total = cart_totals.tax_total;
                            if(grand_total <= 0){
                                Debug.print("createQuoteForCart grand_total is 0" # debug_show(cart_totals));
                                return null;
                            };                            

                            //Debug.print("calculateTokenDenomination TOKEN " # debug_show(token_details.name));
                            let spot_price_per_unit = latest_quote.value;
                            if(spot_price_per_unit <= 0){
                                Debug.print("calculateTokenDenomination ERROR SPOT PRICE 0 " # debug_show(token_details.name));
                                return null;
                            };

                            //grand total = total value of cart 22.344000
                            //spot price = current value of token 12.499500
                            //token denom = cart / value = 1.78759150366014640585623424937
                            var total_over_price = grand_total / spot_price_per_unit;                                              
                            var token_demo = "";
                            if(token_details.decimals == 8){ //todo make this suck less
                                var demo_int = Utils.convertStringToE8s_new(Float.toText(total_over_price));
                                token_demo := Int.toText(demo_int);
                            }else{
                                token_demo := calculateTokenDenomination(total_over_price, token_details.decimals);
                            };
                            
                            if(Text.size(token_demo) == 0 or token_demo == "0"){                                
                                Debug.print("ERROR BIG problem with parsing token denominations");
                                return null;
                            };

                            var result : SupdTypes.CartQuoteResponse = {
                                grand_total = grand_total;
                                tax_total = tax_total;
                                shipping_total = cart.shipping_total;
                                currency = "USD";
                                currency_symbol = "$";
                                created_at = Utils.now_seconds();
                                updated_at = Utils.now_seconds();                                                    
                                token = token_details;
                                token_currency = token_currency;
                                token_chain = chain_match;                                                         
                                spot_price_per_unit = spot_price_per_unit;  //spot_price_per_unit: Float; //$2959.00
                                token_denomination = token_demo; //token_denomination: Text; // 112 United States Dollar "$" (USD) 0.03788856 Ethereum (ETH)
                                
                                quoted_cart = cart;         
                                dest = "";
                                                               
                            };                                    
                            return ?result;
                        };
                    };
                };
            };           
        };       
       

    };

};