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
import Web3Helper "web3helper";
import TokenF "./TokenFactory";
import CurrencyF "../currency/FXFactory";
import Types "../Types";
import HttpTypes "../http/http.types";
import Utils "../Utils";
import Hex "../Hex";
import Base64 "../Base64";
import Serde "mo:serde";
import { JSON; Candid; CBOR; } "mo:serde";

//All prices in USD as base currency
//loops through services defined and fetches best price for a given token
//more services = better price accuracy at the cost of https outcall congestion
//3/9/2024 - prices are being fetched from a single source and cached FX_CACHE_TIME_SECONDS to avoid outcall congestion
//TODO: - onchain direct prices / threading?
module PriceFactory {

  public class PriceFactory(calling_actor : Text, chain : Types.TokenChain, token : Types.TokenCurrency, testMode : Bool) {

    private let main_actor_id = calling_actor;      
    public let selected_chain : Types.TokenChain = chain;
    public let selected_token : Types.TokenCurrency = token;
    public let TEST_MODE : Bool = testMode;
    let ic : HttpTypes.IC = actor ("aaaaa-aa");

    //pulls USD prices from various open services using a simple average
    public func getConsensusPrice() : async Float {   
      
      //let services : [Types.PriceService] = [#coingecko, #chainlink, #kraken, #testnet];
      let services : [Types.PriceService] = [#testnet]; //TODO: for now using custom service with caching

      //Debug.print("getConsensusPrice STARTED" # debug_show(selected_token));      
      var priceCandidates = List.nil<Float>();
      for (service in services.vals()) {  //TODO: try catch
        switch service {          
          case (#coingecko) { 
            let geckoPrice = await getPriceCoingecko();
            Debug.print("getConsensusPrice - geckoPrice: " # debug_show(geckoPrice));
            priceCandidates := List.push(geckoPrice, priceCandidates);
          };
          case (#chainlink) { 
            let chainlinkPrice = await getPriceChainlink();
            Debug.print("getConsensusPrice - chainlinkPrice: " # debug_show(chainlinkPrice));
            priceCandidates := List.push(chainlinkPrice, priceCandidates);
           };
          case(#kraken){
            //Debug.print("getConsensusPrice - kraken: " # debug_show(""));
          };
          case(#testnet){
            let testnetPrice = await getPriceTestnet();
            Debug.print("getConsensusPrice - testnetPrice: " # debug_show(testnetPrice));
            priceCandidates := List.push(testnetPrice, priceCandidates);
          };
          case (_) { 
            //throw Error.reject("Unsupported price service");
            let zero_price : Float = 0;
            priceCandidates := List.push(zero_price, priceCandidates);      
            let nprice : Float = -1;
            priceCandidates := List.push(nprice, priceCandidates);
           };

        };
        Debug.print("getConsensusPrice service : " # debug_show(service));
      };      
     
      //for SLA check against length of prices == active services     
      var prices = List.filter<Float>(priceCandidates, func n {
        return n > 0;
      });

      if(List.size(prices) == 0){
        Debug.print("prices is empty after removing outliers " # debug_show(selected_token));
        return 0.0;
      };

      var candidates = List.toArray(prices);
      Debug.print("getConsensusPrice candidates " # debug_show(candidates));
      var avg = Utils.averageFloats(candidates, true);
      Debug.print("getConsensusPrice avg: "  # debug_show(avg));
      Debug.print("getConsensusPrice FINISHED" # debug_show(selected_token));      
      return avg;
    };

    //for a given token, fetches the consensus price in usd and returns a TokenQuote
    public func getTokenQuote() : async ?Types.TokenQuote {      
      var tf = TokenF.TokenFactory(true);
      var bootstrap = tf.getTokens();
      let match = Array.find<(Types.Token)>(bootstrap, func(x) = x.token_type == selected_token);
      switch(match){
          case null return null;
          case(?match){              
              var quote_in_usd : Float = 0.00;
              let consensus_price = await getConsensusPrice();
              quote_in_usd := consensus_price;
              if(quote_in_usd <= 0.0){
                Debug.trap("problem with the getTokenQuote parser ");
                return null;
              };
              let formatted_price = Float.format(#fix 4, quote_in_usd);              
              var mname = Text.toUppercase(match.name);
              var q : Types.TokenQuote = {
                  name = mname;
                  symbol = mname;
                  value = quote_in_usd;
                  value_str = formatted_price;
                  created_at = Utils.now_seconds();
                  source = ?"testnet";
                  currency_type = #usd;
                  token_type = match.token_type;
              };
              return ?q;
          };
      };

    };

    
    
    /*----------------PRICE SERVICES --------------------------------*/   
    private func getPriceCoingecko() : async Float {

      let mappings = [
        (#icp, "internet-computer"), 
        (#eth, "ethereum"),
        (#btc, "bitcoin"),
        (#sol, "solana"),
        (#weth, "weth"),
        (#usdt, "tether"),
        (#dai, "dai"),
        (#usdc, "usd-coin"),
        (#ckbtc, "chain-key-bitcoin"),
        (#cketh, "chain-key-ethereum"),
        (#wbtc, "wrapped-bitcoin"),
        (#exe, "windoge98"),
        (#wtao, "tao"),
        (#bonk, "bonk")
        //(#sneed, "coingecko sneed na")
      ];

      let match = Array.find<(Types.TokenCurrency, Text)>(mappings, func(x) = x.0 == selected_token);
      if(match == null){
        return 0;
      };
      let ?(ticker, coingecko_id) = match else return 0;
      let cgurl = "https://api.coingecko.com/api/v3/simple/price?ids=" # coingecko_id # "&vs_currencies=usd";
      let idempotencyKey = Utils.textToSha(cgurl);
      //Debug.print("fetching prices from idempotencyKey ... " # debug_show(idempotencyKey));
      let httpRequest : HttpTypes.HttpRequestArgs = {
        url = cgurl;        
        max_response_bytes = ?Nat64.fromNat(2000);
        headers = [
            { name = "Content-Type"; value = "application/json" },
            //{ name = "Idempotency-Key"; value = idempotencyKey },
        ];
        body = null;
        method = #get;
        transform = null;
      };
    
      Cycles.add(500_000_000);

      // Send the request
      let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);
      Debug.print("HttpResponsePayload STATUS: " # debug_show(httpResponse.status));      
      if (httpResponse.status == 200) {                
          let response_body : Blob = Blob.fromArray(httpResponse.body);
          let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
              case (null) { "No value returned from service" };
              case (?decoded_text) {
                  //Debug.print("Decoded text: " # debug_show(decoded_text));
                  // Decoded text: "{"ethereum":{"usd":2427.22}}"
                  // let options: Serde.Options = 
                  // { 
                  //   renameKeys = [(coingecko_id, "result")]
                  // };
                  // Debug.print("renaming key: " # debug_show(coingecko_id));
                  // let #ok(blob) = JSON.fromText(decoded_text, null) else return 0;
                  // "{"ethereum":{"usd":2427.22}}"
                  var thing = Text.replace(decoded_text, #char '{', "");
                  thing := Text.replace(thing, #char '}', "");
                  thing := Text.replace(thing, #char '\"', "");                  
                  let parts : Iter.Iter<Text> = Text.split(thing, #text ":");
                  let b = Iter.toArray(parts);
                  if(b.size() != 3){
                    Debug.print("failed coingeckoResponse parsing " # debug_show(b));
                    return 0;
                  };
                  let price = await Utils.textToFloat(b[2]);                  
                  return price;
              };
          };
          Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
          return 0;
      } else {
          Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
          return 0;
      };
      return 0;
    };
   

    private func getPriceChainlink() : async Float {      
      var provider = await Utils.randomProvider();
      if(selected_token == #icp or selected_token == #bonk){ 
        provider := "https://rpc.ankr.com/optimism"; //icp/bonk contracts on optimism
        Debug.print("CHAINLINK OPTIMISM PROVIDER ... " # debug_show(provider));
      };
      let web3 = Web3Helper.Web3(provider, true);
      let usd_price = await web3.chainlink_latestPriceUSD(selected_token);
      Debug.print("fetching prices from CHAINLINK ... " # debug_show(usd_price));
      return await Utils.textToFloat(usd_price);
    };

    //TODO: - not implemented
    private func getPriceKraken() : async Float {
      Debug.trap("not implemented");
      let mappings = [
        (#icp, "ICPUSD"), 
        (#eth, "ETHUSD"),
        (#btc, "BTCUSD"),
        (#sol, "SOLUSD"),
        (#weth, "WETHUSD"),
        (#usdt, "USDTUSD"),
        (#dai, "DAIUSDT"),
        (#usdc, "USDCUSD"),
        (#ckbtc, ""),
        (#cketh, ""),
        (#wbtc, "WBTCUSD")
      ];

      let match = Array.find<(Types.TokenCurrency, Text)>(mappings, func(x) = x.0 == selected_token);
      if(match == null){
        return 0;
      };
      Debug.print("KRAKEN match " # debug_show(match));

      let ?(ticker, kraken_id) = match else return 0;
      
      Debug.print("KRAKEN ticker " # debug_show(ticker));
      Debug.print("KRAKEN slug " # debug_show(kraken_id));
      Debug.print("fetching prices from KRAKEN ... " # debug_show(match));      
      
      let cgurl = "https://api.kraken.com/0/public/Ticker?pair=" # kraken_id;

      let idempotencyKey = Utils.textToSha(cgurl);
      Debug.print("fetching prices from idempotencyKey ... " # debug_show(idempotencyKey));

      let httpRequest : HttpTypes.HttpRequestArgs = {
        url = cgurl;
        //max_response_bytes = ?Nat64.fromNat(250_000); //TODO:
        max_response_bytes = ?Nat64.fromNat(2000); //TODO:
        headers = [
            { name = "Content-Type"; value = "application/json" },
            //{ name = "Idempotency-Iey"; value = idempotencyKey },
        ];
        body = null;
        method = #get;
        transform = null;
      };

      //49.14M + 5200 * request_size + 10400 * max_response_bytes
      // 49.14M + (5200 * 1000) + (10400 * 1000) = 64.74M
      Cycles.add(1_000_000_000);

      // Send the request
      let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);  
      
      Debug.print("HttpResponsePayload STATUS: " # debug_show(httpResponse.status));
      // Check the response
      if (httpResponse.status == 200) {                
          let response_body : Blob = Blob.fromArray(httpResponse.body);
          let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
              case (null) { "No value returned from service" };
              case (?decoded_text) {
                  Debug.print("Decoded text: " # debug_show(decoded_text));
                  //{"error":[],
                  //"result": {"XXBTZUSD": {"a": ["47298.50000","2","2.000"],"b":["47298.40000","4","4.000"],"c":["47298.40000","0.00011143"],....."o":"47127.10000"}}}
                  var price = -1.0;
                  return price;
              };
          };
          Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
          return 0;
      } else {
          Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
          return 0;
      };
      return 0;
    };


    //TODO: temp workaround until https outcalls resolved
    private func getPriceTestnet() : async Float {
      let mappings = [
        (#icp, "icp"), 
        (#eth, "eth"),
        (#btc, "btc"),
        (#sol, "sol"),
        (#weth, "weth"),
        (#usdt, "usdt"),
        (#dai, "dai"),
        (#usdc, "usdc"),
        (#ckbtc, "ckbtc"),
        (#cketh, "cketh"),
        (#wbtc, "wbtc"),
        (#exe, "exe"),
        (#wtao, "wtao"),
        (#bonk, "bonk"),
      ];
        
      let match = Array.find<(Types.TokenCurrency, Text)>(mappings, func(x) = x.0 == selected_token);
      if(match != null){
            let ?(ticker, key_name) = match else return 0;
            let price = await getUSDTokenPriceWorkaround(key_name);
            switch(price){
              case null return -1.00;
              case(?price){
                return price;
              };
            };
        };
        return 0;
    };

    public type TokenResult = {        
      name: ?Text;
      usd: ?Text;
    };

    //[{"name":"btc","usd":61868},{"name":"icp","usd":13.49},{"name":"ckbtc","usd":62665},{"name":"cketh","usd":3469.74},{"name":"dai","usd":0.99906},
    //{"name":"eth","usd":3432.29},{"name":"weth","usd":3404.15},{"name":"sol","usd":130.13},{"name":"usdt","usd":1},
    //{"name":"usdc","usd":1},{"name":"exe","usd":0.234284},{"name":"wbtc","usd":61844}]
    
    //temp workaround until onchain pricing/https outcall 429  TODO:        
    private func getUSDTokenPriceWorkaround(token : Text) : async ?Float {
      Debug.print("getUSDTokenPriceWorkaround  START ");      
      let jsonText = await getTokenJsonFromSupercartService(token);
      let #ok(blob) = JSON.fromText(jsonText, null) else return null; // broken service
      let token_results : ?[TokenResult] = from_candid(blob);
      switch(token_results){
          case null return null;
          case(?token_results){                
              //Debug.print("getUSDTokenPriceWorkaround  token_results " # debug_show(token_results));
              let match : TokenResult = Array.filter<TokenResult>(token_results, func x = x.name == ?token)[0];
              let cg_price = Option.get(match.usd, "0");
              let p = await Utils.textToFloat(cg_price);
              return ?p;
          };
      };
      return null;
    };

    private func getTokenJsonFromSupercartService(token : Text) : async Text {        
        let ic : HttpTypes.IC = actor ("aaaaa-aa");
        if(Text.size(main_actor_id) == 0){
          Debug.print("ERROR - no actor found for context !");
          return "0";
        };
        let main_actor : HttpTypes.MainActor = actor (main_actor_id);
        //Debug.print("STARTING getTokenJsonFromSupercartService " # debug_show(Utils.now()));        
        let idempotencyKey : Text = Utils.textToSha(Text.concat("getTokenJsonFromSupercartService workaround tokens", token));
        //Debug.print("idempotencyKey " # debug_show(idempotencyKey));

        let custom_webhook_url = "https://tokens--supercartd.netlify.app/.netlify/functions/notify";
        let max_expected_response = 5000;

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

        //TODO: costing estimation
        //HTTPS outcalls: The cost for an HTTPS outcall is calculated using the formula (3_000_000 + 60_000 * n) * n 
        //for the base fee and 400 * n each request byte 
        //and 800 * n for each response byte, where n is the number of nodes in the subnet. 

        //49.14M + 5200 * request_size + 10400 * max_response_bytes
        // 49.14M + (5200 * 1000) + (10400 * 1000) = 64.74M  
        // http_outcall_cost = per_call_cost + per_request_byte_cost * request_size + per_response_byte_cost * max_response_size
        // scaling_factor = subnet_size / 13
        // total_cost = scaling_factor * http_outcall_cost
        
        Cycles.add(500_000_000);        
        let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);        
        if (httpResponse.status == 200) {
            Debug.print("HttpResponsePayload 200");
            let response_body : Blob = Blob.fromArray(httpResponse.body);
            let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {                
                case (null) { "No value returned" };
                case (?decoded_text) {
                    //Debug.print("?decoded_text " # debug_show(decoded_text));
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


  };
};