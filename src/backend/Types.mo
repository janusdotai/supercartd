module Types { 
  
  //add new currency here and update FXFactory
  public type Currency = {
    #usd; 
    #eur;
    #cad;
    #gbp;
    #chf;
  };  

  //add new chain here and update TokenFactory
  public type TokenChain = {
    #btc_mainnet;
    #icp_mainnet;
    #icp_testnet;
    #eth_mainnet;
    #eth_testnet;
    #sol_mainnet;
    
    #tao_mainnet;    
    #op_mainnet;       
    #arb_mainnet;    
    #base_mainnet;    
    #ftm_mainnet;
    #bsc_mainnet;
  };

  //add new token here and update TokenFactory
  public type TokenCurrency = {    
    #icp;
    #eth;
    #btc;
    #sol;
    #weth;   
    #usdt;
    #usdc;
    #dai;
    #ckbtc;
    #cketh;
    #wbtc;
    #wtao;
    #exe;  //memes for testing
    #sneed;    
    #bonk;    
    #test; //qa 
  };
  
  //add new service here and update PriceFactory with your implementation
  public type PriceService = {    
    #icpservice; //onchain
    #coingecko; //offchain
    #chainlink; //onchain
    #coinmarketcap; //offchain
    #kraken; //offchain
    #testnet; //offchain
  };
  
  public type Merchant = {
    cid: Text;
    is_enabled : Bool;
    name : Text;
    email_notifications : Bool;
    email_address : Text; //todo: encrypt but service needs access to be able to send notifications
    phone_notifications : Bool;
    phone_number : Text;
    created_at: Nat64;
    updated_at: Nat64;
  };

  public type TaxMode = {
    #inclusive;
    #exclusive;
  };

  public type Product = {    
    pid: Text;    
    cid: Text;
    foreign_key : ?Text;
    is_enabled: Bool;
    sku: Text;
    name: Text;
    description: Text;
    description2: ?Text;
    price: Float;    
    tax1rate: Float;
    tax2rate: Float;
    tax_mode: TaxMode;
    created_at: Nat64;
    updated_at: Nat64;
    image_url: ?Text;
    tags: ?[Text];
  };

  public type CheckoutStoreView = {
    created_at: Nat64;
    merchant: Merchant;
    products: ?[Product];
    chains: ?[TokenChain];
  };

  public type CartProduct = {
    sku: Text;
    qty: Int;
    price: Float;
    tax1rate: Float;
    tax2rate: Float;    
  };

  public type ShoppingCart = {
    cid: Text;
    created_at: Nat64;
    updated_at: Nat64;   
    items: [CartProduct];
    currency: Text;
    active_wallet: Text;
    active_chain: Text;
    shipping_total: Float;
  };

  public type CartTotals = {
    sub_total : Float;
    tax_total : Float;
    grand_total : Float;
    shipping_total : Float;
    additional_fee : Float;
    discount: Float;
  };

  public type CartQuoteResponse = {
    grand_total : Float; //$112.00
    tax_total: Float; //12
    shipping_total: Float; //0
    currency: Text; //usd
    currency_symbol: Text; //$
    created_at: Nat64;
    updated_at: Nat64;
    token: Token;
    token_currency: TokenCurrency; //eth      
    token_chain: TokenChain; //eth_mainnet
    token_denomination: Text; // 112 United States Dollar "$" (USD) 0.03788856 Ethereum (ETH)
    spot_price_per_unit: Float; //$2959.00
    quoted_cart: ShoppingCart;    
    dest: Text;      
  }; 

  public type OrderStatus = {
    #test;
    #pending; //new
    #processing; //payment received
    #shipped;
    #complete;
  };

  public type Order = {
    oid: Text;
    cid: Text;
    foreign_key : ?Text;
    onchain_tx: Text;
    block_height: Text;
    chain: TokenChain;
    currency: Currency;
    grand_total: Float;
    status: OrderStatus;
    created_at: Nat64;
    updated_at: Nat64;
  };

  public type PubOrderReceipt = {
    rid: Text;
    oid: Text;
    cid: Text;
    created_at: Nat64;
    updated_at: Nat64;
    sub_total: Float;
    tax_total: Float;
    shipping_total: Float;
    total: Float;
    discount: Float;
    gas: Text;
    additional_fee: Float;
    currency: Currency;
    onchain_tx: Text;
    block_height: Text;
    chain: TokenChain;
    token_currency: TokenCurrency;
    token_slug: Text;
  };

  public type OrderReceipt = {
    rid: Text;
    oid: Text;
    cid: Text;
    created_at: Nat64;
    updated_at: Nat64;

    items: [CartProduct];   

    sub_total: Float;
    tax_total: Float;
    shipping_total: Float;
    total: Float;
    discount: Float;
    gas: Text;
    additional_fee: Float;
    currency: Currency;

    onchain_tx: Text;
    block_height: Text;
    chain: TokenChain;
    token_currency: TokenCurrency;
    token_slug: Text;
    
    source_wallet: Text;
    dest_wallet: Text;
    
    //todo: these are not currently used as there is no shipping implemenation
    email: ?Text;
    first_name: ?Text;
    last_name: ?Text;
    shipping_address1: ?Text;
    shipping_address2: ?Text;
    shipping_city: ?Text;
    shipping_state: ?Text;
    shipping_country: ?Text;
    shipping_zip: ?Text;
    shipping_phone: ?Text;
    extra_data: ?[Text];
  };
  
  
  public type CurrencyQuote = {
    name: Text; //USD, EUR
    symbol: Text; //$, €, £
    value: Float; //0.75
    value_str: Text; //0.75  
    created_at: Nat64;
    source: ?Text;
    currency_type: Currency;
    description: ?Text;
  };
  
  public type TokenQuote = { 
    name: Text;
    symbol: Text;
    value: Float;
    value_str: Text;
    created_at: Nat64;
    source: ?Text;
    currency_type: Currency;
    token_type: TokenCurrency;
  };
  
  public type Token = {    
    name: Text;
    decimals: Nat;
    contract: Text;
    created_at: Nat64;
    abi: Text;   
    chains: [TokenChain];
    token_type: TokenCurrency;
    last_quote: ?TokenQuote;
    description: Text;
    slug: Text;
  };
  
  public type CheckoutPaymentSetting = {
    cid: Text;    
    guid: Text;
    created_at: Nat64;
    updated_at: Nat64;
    is_enabled: Bool;
    token_type: TokenCurrency;
    chain: TokenChain;
    dest: Text;    
    sig: ?Blob;
 };

  public type PubSetting = {
    cid: Text;    
    guid: Text;    
    created_at: Nat64;
    updated_at: Nat64;    
    is_enabled: Bool;
    token_type: TokenCurrency;
    chain: TokenChain;
  };

  public type TransactionReceipt = {
    status: Bool;
    transactionHash: Text;
    transactionIndex: Nat;
    blockHash: Text;
    blockNumber: Nat;
    contractAddress: Text;
    cumulativeGasUsed: Nat;
    gasUsed: Nat;
    chain: TokenChain;
    token_type: TokenCurrency;
  };

  public type Transaction = {
    hash: Text;
    nonce: Nat;
    blockHash: Text;
    blockNumber: Nat;
    transactionIndex: Nat;
    from: Text;
    to: Text;
    value: Text;
    gas: Nat;
    gasPrice: Text;
    input: Text;
    chain: TokenChain;
    token_type: TokenCurrency;
  };

  public type CoingeckoResponse = {
    result: ?CoingeckoResponseDetail;
    ethereum: ?CoingeckoResponseDetail;
    bitcoin: ?CoingeckoResponseDetail;
  };

  public type CoingeckoResponseDetail = {
    usd: ?Float;
  };

  public type Response<T> = {
    status : Nat16;
    status_text : Text;
    data : ?T;
    error_text : ?Text;
  };

  public type CheckoutLog = { 
    cid: Text;   
    status: Nat16;
    status_text: Text;
    created_at: Nat64;
    owner: Text;
  };


 };
