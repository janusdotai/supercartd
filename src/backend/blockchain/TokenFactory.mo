import Types "../Types";
import Utils "../Utils";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Float "mo:base/Float";


//All tokens and chains are defined here
//to add a new token: add to getTokens
//to add a new chain: add to getChains
//Ensure you update the PriceFactory for your new token so prices can be fetched
module TokenFactory {
  
  public class TokenFactory (_test_mode : Bool) {    

    public let TEST_MODE = _test_mode;

    public func getChains() : [Types.TokenChain] {      
      if(TEST_MODE){
        return [ #btc_mainnet, #icp_mainnet, #icp_testnet, #eth_mainnet, #eth_testnet, #op_mainnet, #sol_mainnet ];
      };
      return [ #icp_mainnet, #eth_mainnet, #sol_mainnet ]; 
    };

    //maps eth_mainnet to #eth_mainnet
    public func chainFromText(chain : Text) : ?Types.TokenChain {
      for(chain_type in getChains().vals()){
        var chain_text = chainToText(chain_type);
        var lower = Text.toLowercase(chain);
        if(Text.equal(lower, chain_text)){
          return ?chain_type;
        };
      };
      return null;
    };

    //maps eth_mainnet to #eth_mainnet eagarly
    public func chainFromTextOrTrap(chain : Text) : Types.TokenChain {
      let c = chainFromText(chain);
      switch(c){
        case null Debug.trap("oh wrong chain");
        case(?c){
          return c;
        };
      };
    };
    
    public func chainToText(chain : Types.TokenChain) : Text {
      switch chain {
        case(#btc_mainnet) "btc_mainnet";
        case(#icp_mainnet) "icp_mainnet";
        case(#icp_testnet) "icp_testnet";        
        case(#eth_mainnet) "eth_mainnet";
        case(#eth_testnet) "eth_testnet";        
        case(#sol_mainnet) "sol_mainnet";       
        case(#tao_mainnet) "tao_mainnet";       
        case(#op_mainnet) "op_mainnet";       
        case(#arb_mainnet) "arb_mainnet";       
        case(#base_mainnet) "base_mainnet";       
        case(#ftm_mainnet) "ftm_mainnet";
        case(#bsc_mainnet) "bsc_mainnet";
      };
    };
   
    //maps icp > #icp
    public func getToken(name : Text) : async Types.TokenCurrency {
      assert(Text.size(name) > 2 and Text.size(name) < 20);
      let t = getTokens();
      let m = Text.toUppercase(name);  
      let match = Array.find<Types.Token>(t, func(x) = Text.toUppercase(x.name) == m);
      switch(match){
        case null Debug.trap("getToken could not match " # debug_show(m));
        case (?match){
          return match.token_type;
        };
       };
    };    

    //maps chain-key-bitcoin > the token
    public func getTokenBySlug(slug : Text) : async ?Types.Token {
      let t = getTokens();
      let m = Text.toUppercase(slug);
      let match = Array.find<Types.Token>(t, func(x) = Text.toUppercase(x.slug) == m);
      switch(match){
        case null return null;
        case (?match){
          return ?match;
        };
       };      
    };

    //maps #icp + #icp_mainnet = the token (on first chain match)
    public func getTokenDetails(token : Types.TokenCurrency, chain : Types.TokenChain) : async ?Types.Token {      
      let all_tokens = getTokens();
      let token_matches = Array.filter<Types.Token>(all_tokens, func(x : Types.Token) : Bool {
        x.token_type == token 
      });
      for(search_token in token_matches.vals()){
        var chain_match = Array.find<Types.TokenChain>(search_token.chains, func(x) = x == chain);
        if(chain_match != null){
          //Debug.print("getTokenDetails subSearch returned " # debug_show(chain_match));
          return ?search_token;
        };
      };
      return null;
    };    

    //maps #icp + #icp_mainnet = the token eagerly
    public func locateTokenDetails(token : Types.TokenCurrency, chain : Types.TokenChain) : async Types.Token {      
        let match = await getTokenDetails(token, chain);
        switch(match){
          case null Debug.trap("ohh nooo");
          case(?match){
            return match;
          };
        };
    };

    //maps #icp > [tokens]
    public func getTokenMappings(token : Types.TokenCurrency) : async [Types.Token] {
      let t = getTokens();            
      let match = Array.filter<Types.Token>(t, func(x) = x.token_type == token);
      return match;
    };
   
    //Platform tokens 
    //add your implemenation here and include in the return results
    public func getTokens() : [Types.Token]{   

      //todo: no front end implemenation
      // var btc : Types.Token = {
      //   name = "BTC";
      //   token_type = #btc;
      //   decimals = 8;
      //   contract = "";
      //   created_at = Utils.now_seconds();
      //   abi = "";
      //   chains = [#btc_mainnet];
      //   last_quote = null;
      //   description = "Bitcoin";
      //   slug = "bitcoin";
      // };

      var icp : Types.Token = {
        name = "ICP";
        token_type = #icp;
        decimals = 8;
        contract = "ryjl3-tyaaa-aaaaa-aaaba-cai";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#icp_mainnet];
        last_quote = null;
        description = "Internet Computer Protocol";
        slug = "icp";
      };

      var eth : Types.Token =  {
        name = "ETH";
        token_type = #eth;
        decimals = 18;
        contract = ""; //NATIVE
        created_at = Utils.now_seconds();
        abi = ""; 
        chains = [#eth_mainnet];
        last_quote = null;
        description = "Ethereum";
        slug = "ethereum";
      };

      var ethTest : Types.Token =  {
        name = "ETH";
        token_type = #eth;
        decimals = 18;
        contract = ""; //NATIVE
        created_at = Utils.now_seconds();
        abi = ""; 
        chains = [#eth_testnet];
        last_quote = null;
        description = "Ethereum (Sepolia)"; 
        slug = "ethereumSepolia";
      };

      var weth : Types.Token =  {
        name = "WETH";
        token_type = #weth;
        decimals = 18;
        contract = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
        created_at = Utils.now_seconds();        
        abi = "";
        chains = [#eth_mainnet];
        last_quote = null;
        description = "Wrapped Ethereum";
        slug = "weth";
      };

      // var wethTest : Types.Token =  {
      //   name = "tWETH";
      //   token_type = #weth;
      //   decimals = 18;
      //   contract = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";  //sepolia WETH //0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323
      //   created_at = Utils.now_seconds();        
      //   abi = "";
      //   chains = [#eth_testnet];
      //   last_quote = null;
      //   description = "Wrapped Ethereum (Sepolia)";
      //   slug = "weth-sepolia";
      // };      

      var dai : Types.Token =  {         
        name = "DAI";
        token_type = #dai;
        decimals = 18;
        contract = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
        created_at = Utils.now_seconds();
        
        abi = "";
        chains = [#eth_mainnet];
        last_quote = null;
        description = "Dai Stablecoin";     
        slug = "dai";  
      };

      var usdt : Types.Token =  {
        name = "USDT";
        token_type = #usdt;
        decimals = 6;
        contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        created_at = Utils.now_seconds();         
        abi = "";
        chains = [#eth_mainnet];        
        last_quote = null;
        description = "Tether";
        slug = "usdt";
      };

      var usdc : Types.Token =  {
        name = "USDC";
        token_type = #usdc;
        decimals = 6;
        contract = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
        created_at = Utils.now_seconds();         
        abi = "";
        chains = [#eth_mainnet];
        last_quote = null;
        description = "Circle Coin"; 
        slug = "usdc";
      };

      // var test_token : Types.Token = {
      //   name = "TEST";
      //   token_type = #test;
      //   decimals = 6;
      //   contract = "not valid";
      //   created_at = Utils.now_seconds();
      //    
      //   abi = "";
      //   chains = [#eth_mainnet, #eth_testnet, #icp_mainnet, #icp_testnet]; 
      //   last_quote = null;
      //   description = "Test Coin Invalid";
      //   slug = "test";
      // };


      var sol : Types.Token = {
        name = "SOL";
        token_type = #sol;
        decimals = 9;
        contract = "";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#sol_mainnet];
        last_quote = null;
        description = "Solana";
        slug = "solana";
      };

      var exe : Types.Token = {
        name = "EXE";
        token_type = #exe;
        decimals = 8;
        contract = "rh2pm-ryaaa-aaaan-qeniq-cai";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#icp_mainnet];
        last_quote = null;
        description = "Windoge98";
        slug = "windoge98";
      };

      var ckEth : Types.Token = {
        name = "ckETH";
        token_type = #cketh;
        decimals = 18;
        contract = "ss2fx-dyaaa-aaaar-qacoq-cai"; 
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#icp_mainnet];
        last_quote = null;
        description = "Chain-key Ethereum";
        slug = "chain-key-ethereum";
      };

      var ckBTC : Types.Token = {
        name = "ckBTC";
        token_type = #ckbtc;
        decimals = 8;
        contract = "mxzaz-hqaaa-aaaar-qaada-cai"; 
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#icp_mainnet];
        last_quote = null;
        description = "Chain-key Bitcoin";
        slug = "chain-key-bitcoin";
      };


      var sneed : Types.Token = {
        name = "SNEED";
        token_type = #sneed;
        decimals = 8;
        contract = "hvgxa-wqaaa-aaaaq-aacia-cai";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#icp_mainnet];
        last_quote = null;
        description = "Sneed";
        slug = "sneed";        
      };

      var bonk : Types.Token = {
        name = "BONK";
        token_type = #bonk;
        decimals = 5;
        contract = "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#sol_mainnet];
        last_quote = null;
        description = "Bonk";
        slug = "bonk";        
      };

      var wtao : Types.Token = {
        name = "wTAO";
        token_type = #wtao;
        decimals = 9;
        contract = "0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44";
        created_at = Utils.now_seconds();
        abi = "";
        chains = [#eth_mainnet];
        last_quote = null;
        description = "Wrapped TAO";
        slug = "wtao";        
      };


      if(TEST_MODE){
        return [icp, eth, ethTest, weth, dai, usdt, usdc, exe, ckEth, ckBTC, sol, sneed, wtao ];
      };
      
      return [icp, eth, weth, dai, usdt, usdc, sol ];

    };

   
  };
};

 