
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
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
import Error "mo:base/Error";
import List "mo:base/List";
import AssocList "mo:base/AssocList";
import Float "mo:base/Float";
import Types "../Types";
import Utils "../Utils";
import Map "mo:map/Map";
import HttpTypes "../http/http.types";
//import { JSON; Candid; } "mo:serde";
import { JSON; Candid; CBOR; URLEncoded } "mo:serde";
import Web3Helper "../blockchain/web3helper";

//General class to help with FX rates
//3/9/2024 using a temp price feed service for rates 10 min cached for https outcall performance
//todo use exchange rate canister
module {  
   
    public class CurrencyFactory(calling_actor : Text, _test_mode : Bool) {
    
        public let TEST_MODE = _test_mode;

        private let main_actor_id = calling_actor;

        //convert from USD > #usd
        public func getCurrency(name : Text) : async Types.Currency {
            assert(Text.size(name) == 3);
            let fx = getFxBootstrap();
            let match = Array.find<Types.CurrencyQuote>(fx, func(x) = x.name == Text.toUppercase(name));
            switch(match){
                case null Debug.trap("getToken could not match " # debug_show(name));
                case (?match){
                    return match.currency_type;
                };
            };
        };

        //convert from #usd to USD
        public func currencyToText(currency : Types.Currency) : Text {
            switch(currency){
                case(#eur) {
                    return "EUR";
                };
                case(#cad) {
                    return "CAD";
                };
                case(#usd) {
                    return "USD";
                };
                case(#gbp) {
                    return "GBP";
                };
                case(#chf) {
                    return "CHF";
                };
            };
        };

        //get latest fx
        public func getQuote(currency : Types.Currency) : async ?Types.CurrencyQuote {    
            var bootstrap =  getFxBootstrap();
            if(currency == #usd){ //we peg everything to 1 USD
                return Array.find<(Types.CurrencyQuote)>(bootstrap, func(x) = x.currency_type == currency);
            };       
            let match = Array.find<(Types.CurrencyQuote)>(bootstrap, func(x) = x.currency_type == currency);
            switch(match){
                case null return null;
                case(?match){
                    //var quote_in_usd = await getFXChainlink(currency);   
                    var quote_in_usd = await getFXDimiWorkaround(currency);
                    //Debug.print("getQuote ... " # debug_show(quote_in_usd));               
                    let value_str = Float.toText(quote_in_usd);
                    let msymbol = Text.toUppercase(match.symbol);
                    let q : Types.CurrencyQuote = {
                        name = match.name;
                        symbol = msymbol;
                        value = quote_in_usd;
                        value_str = value_str;
                        created_at = Utils.now_seconds();
                        source = ?"testnet service";
                        currency_type = match.currency_type;
                        description = match.description;
                    };
                    return ?q;
                };
            };        
        };
    

        private func getFXChainlink(currency : Types.Currency) : async Float {
            //let provider = "https://eth.llamarpc.com";
            let provider = await Utils.randomProvider();
            let web3 = Web3Helper.Web3(provider, true);
            let usd_price = await web3.chainlink_latestFxRateUSD(currency);
            //Debug.print("getFXChainlink ... " # debug_show(usd_price));
            return await Utils.textToFloat(usd_price);
        };

        //todo - for now just to demo we'll use custm rate feeds because initial algorithm
        //for price feeds is not working on production
        //these rates are cached for 10 minutes and calling them inbtween intervals
        //shuld yield idential results to satisfy consensus
        private func getFXDimiWorkaround(currency : Types.Currency) : async Float {
            Debug.print("getFXDimiWorkaround " # debug_show(currency));
            let rate = await getUSDForexRateWorkaround(currency);
            switch(rate){
                case null return -1.00;
                case(?rate){
                    return rate;
                };
            };
        };
        
        //boostrap
        public func getFxBootstrap() : [Types.CurrencyQuote] {

            let usd : Types.CurrencyQuote = { 
                name = "USD";
                symbol = "$";
                value = 1.0;
                value_str = "1.00";
                source = ?"cache";            
                created_at = Utils.now_seconds();
                currency_type = #usd;
                description = ?"US Dollar";
            };
            let cad : Types.CurrencyQuote = { 
                name = "CAD";
                symbol = "$";
                value = 0.75;
                value_str = "0.75";
                source = ?"cache";            
                created_at = Utils.now_seconds();
                currency_type = #cad;
                description = ?"Canadian Dollar";
            };
            let eur : Types.CurrencyQuote = { 
                name = "EUR";
                symbol = "€";
                value = 1.07;
                value_str = "1.07";
                source = ?"cache";            
                created_at = Utils.now_seconds();
                currency_type = #eur;
                description = ?"Euro";
            };
            let gbp : Types.CurrencyQuote = { 
                name = "GBP";
                symbol = "£";
                value = 1.26;
                value_str = "1.26";
                source = ?"cache";
                created_at = Utils.now_seconds();
                currency_type = #gbp;
                description = ?"British Pound";
            };
            let chf : Types.CurrencyQuote = { 
                name = "CHF";
                symbol = "₣";
                value = 1.13;
                value_str = "1.13";
                source = ?"cache";
                created_at = Utils.now_seconds();
                currency_type = #chf;
                description = ?"Swiss Franc";
            };

            return [usd, cad, eur, gbp, chf];
        };

        public type ForexResult = {        
            alphaCode: ?Text;
            inverseRate: ?Float;
        };
    
        public func getForexJsonFromSupercartService(currency : Types.Currency) : async Text {
            // Managment canister
            let ic : HttpTypes.IC = actor ("aaaaa-aa");            
            let main_actor : HttpTypes.MainActor = actor (main_actor_id);
            if(Text.size(main_actor_id) < 4){
                Debug.print("ERROR getForexJsonFromSupercartService with no actor for transform ");
                return "0";
            };

            Debug.print("STARTING getForexJsonFromSupercartService " # debug_show(Utils.now()));        
            let idempotencyKey : Text = Utils.textToSha(Text.concat("getForexJsonFromSupercartService workaround fx", currencyToText(currency)));
            let custom_webhook_url = "https://supercart-fx.netlify.app/.netlify/functions/notify";
            let max_expected_response = 1000;
            
            let transform_context : HttpTypes.TransformRawResponseFunction = {
                function = main_actor.transform_response;
                context = Blob.fromArray([]);
            };
            
            let httpRequest : HttpTypes.HttpRequestArgs = {            
                url = custom_webhook_url;
                max_response_bytes = ?Nat64.fromNat(max_expected_response);
                headers = [
                    { name = "Content-Type"; value = "application/json" },
                    { name = "Idempotency-Key"; value = idempotencyKey }
                ];
                body = null;
                method = #get;
                transform = ?transform_context;
            };
        
            Cycles.add(500_000_000); //TODO:
            
            let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);            
            if (httpResponse.status == 200) {
                Debug.print("HttpResponsePayload 200");
                let response_body : Blob = Blob.fromArray(httpResponse.body);
                let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {                
                    case (null) { "No value returned" };
                    case (?decoded_text) {
                        Debug.print("?decoded_text " # debug_show(decoded_text));
                        return decoded_text;              
                    };
                };
                Debug.print("ERROR HttpResponsePayload");            
                return "";
            } else {
                Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
                return "";
            };
        };

        private func getUSDForexRateWorkaround(currency : Types.Currency) : async ?Float {            
            let currencyName = currencyToText(currency);
            let jsonText = await getForexJsonFromSupercartService(currency);
            let #ok(blob) = JSON.fromText(jsonText, null) else return null; // broken service
            let fx_rates : ?[ForexResult] = from_candid(blob);
            switch(fx_rates){
                case null return null;
                case(?fx_rates){                
                    Debug.print("getUSDForexRateWorkaround  fx_rates " # debug_show(fx_rates));
                    let match : ForexResult = Array.filter<ForexResult>(fx_rates, func x = x.alphaCode == ?currencyName)[0];              
                    return match.inverseRate;
                };
            };
            return null;
        };

    };

};


