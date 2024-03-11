
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
import Hex "../Hex";
import HttpTypes "../http/http.types";
import SupdTypes "../Types";
import Utils "../Utils";
import TokenFactory "../blockchain/TokenFactory";

//payment types, mappings
module PaymentFactory {        
    
    public class PaymentFactory(merchant : SupdTypes.Merchant, pStore : Map.Map<Text, SupdTypes.CheckoutPaymentSetting>, lStore : Map.Map<Text, SupdTypes.CheckoutLog>){
      
        private let checkout_id : Text = merchant.cid;
        private let payment_store : Map.Map<Text, SupdTypes.CheckoutPaymentSetting> = pStore;
        private let log_store : Map.Map<Text, SupdTypes.CheckoutLog> = lStore;

        private func paymentKey(x : Text) : Trie.Key<Text> {
            return { hash = Text.hash(x); key = x }
        };
        
        private func pre_init() : Bool{
            var result = false;
            if(Text.size(checkout_id) != 64){
                Debug.print("WARNING PaymentFactory.pre_init invalid checkout id !: " # debug_show(checkout_id));
                return false;
            };
            result := true;            
            return result;
        };

        //get all settings for merchant
        public func getPaymentSettings() : [(Text, SupdTypes.CheckoutPaymentSetting)] {            
            let ok = Map.filter(payment_store, thash, func(k : Text, yo : SupdTypes.CheckoutPaymentSetting) : Bool {
                yo.cid == checkout_id;
            });
            return Map.toArray(ok);
        };

        //get specific settting by slug
        public func getPaymentSettingBySlug(slug : Text) : async ?SupdTypes.CheckoutPaymentSetting {
            var tf = TokenFactory.TokenFactory(true);
            var token_match = await tf.getTokenBySlug(slug);
            switch(token_match){
                case null return null;
                case(?token_match){
                    return getPaymentSettingByToken(token_match.token_type, token_match.chains[0]); //todo
                };
            };
        };      

        //get settings by chain
        public func getPaymentsByChain(chain : SupdTypes.TokenChain) : [SupdTypes.CheckoutPaymentSetting] {
            let ok = Map.filter(payment_store, thash, func(k : Text, yo : SupdTypes.CheckoutPaymentSetting) : Bool {
                 yo.cid == checkout_id and yo.chain == chain and yo.is_enabled == true;
            });
            let filteredPaymentTypes = Map.vals(ok);        
            let result : [SupdTypes.CheckoutPaymentSetting] = Iter.toArray(filteredPaymentTypes);
            return result;
        };

        //get specific settting by token currency and chain
        public func getPaymentSettingByToken(token_currency : SupdTypes.TokenCurrency, chain : SupdTypes.TokenChain) : ?SupdTypes.CheckoutPaymentSetting {
            let ok = Map.find(payment_store, func(k : Text, yo : SupdTypes.CheckoutPaymentSetting) : Bool {
                yo.cid == checkout_id and yo.token_type == token_currency and yo.chain == chain;
            });
            switch(ok){
                case null return null;
                case(?ok){
                    return ?ok.1;
                };
            };
        };

        //check that address exists for setting
        public func validateDestAddressExists(token_currency : SupdTypes.TokenCurrency, chain : SupdTypes.TokenChain, address : Text) : async Bool {
            let ok = Map.find(payment_store, func(k : Text, yo : SupdTypes.CheckoutPaymentSetting) : Bool {
                yo.cid == checkout_id and yo.token_type == token_currency and yo.chain == chain and yo.dest == address;
            });
            switch(ok){
                case null return false;
                case(?ok){
                    return true;
                };
            };
        };

        //business logic / extra validation to prevent user error
        private func validateChainAndDestination(chain : SupdTypes.TokenChain, destination : Text) : Bool {
            return true;
        };

        //update a payment setting
        public func updatePaymentSetting(caller : Principal, slug : Text, chain : Text, destination : Text, enabled : Bool) : async Bool {
            assert(pre_init() == true);
            let tf = TokenFactory.TokenFactory(true);
            let token_match = await tf.getTokenBySlug(slug);
            let chain_match = tf.chainFromText(chain);
            switch(token_match){
                case null return false;
                case(?token_match){
                    switch(chain_match){
                        case null{
                            Debug.print("Error could not parse chain match");
                            return false;
                        };
                        case(?chain_match){
                            let ok = validateChainAndDestination(chain_match, destination);
                            if(ok == false){
                                Debug.print("Chain and destination failed to validate ");
                                logMerchant(caller, checkout_id, 500, "Checkout/Payment - ERROR validateChainAndDestination failed ");
                                return false;
                            };

                            var key = Text.toLowercase(merchant.cid # slug # chain); //todo security
                            key :=  Utils.textToSha(key);
                            let pkey = paymentKey(key);

                            let setting_upsert : SupdTypes.CheckoutPaymentSetting = {
                                cid = checkout_id;
                                created_at = Utils.now_seconds();
                                updated_at = Utils.now_seconds();
                                is_enabled = enabled;
                                guid = key;
                                dest = destination;
                                token_type = token_match.token_type;
                                chain = chain_match;
                                sig = null;
                            };
                           
                            let inserted = Map.put(payment_store, thash, pkey.key, setting_upsert);                            
                            if(inserted == null){
                                logMerchant(caller, checkout_id, 201, "Checkout/Payment - INSERTED");
                            }else{
                                logMerchant(caller, checkout_id, 200, "Checkout/Payment - UPDATED");
                            };

                            return true;
                        };

                    };
                };
            };
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
            let ok = Map.put(log_store, thash, sha, l);
            return;
        };
   

    };

};