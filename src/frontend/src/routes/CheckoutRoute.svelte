<script>
import { onMount, afterUpdate } from "svelte";
import { auth, user, token } from "../store/auth.js";
import { getTimestampEpoch, timeAgoFromSecondEpoch, flatten, key2val, ellipsis, pushNotify, stripHtmlTags } from "../store/utils.js"
import { LOADING, removeBusy } from "../store/loader.js";
import shoppingCart from "../store/shoppingCart.js";
import MetaMask from "../providers/metamask.js";
import PlugWallet from "../providers/plug.js";
import PhantomWallet from "../providers/phantom.js";
import TransactionProvider from "../providers/transaction.js";
// import WalletConnect from "../providers/walletconnect.js";
import { WalletProvider, WalletProviderToString, ChainIdToTokenChain } from '../providers/index.js';

export let cid;
const MAX_CART_ITEMS = 5;

let IS_LOADING;
LOADING.subscribe((value) => {
    IS_LOADING = value["status"] == "IDLE" ? false : true;
});

$: CHECKOUT_ENABLED = false;
$: ACTIVE_WALLET_PROVIDER_ID = null;
$: ACTIVE_WALLET_CHAIN_ID = null;
$: ACTIVE_WALLET = null;
$: ACTIVE_TOKEN = null;

let store_view;
let product_catalog = [];
let checkout_name = "loading ... ";
let payment_options = [];

const now_ms = new Date().getTime();
const expires = now_ms + 600000;
//console.log("checkout loaded at " + new Date(now_ms))
//console.log("checkout expires at " + new Date(expires))

let cart_total = 0.00;
let cart_sub_total = 0.00;
let cart_tax_total = 0.00;

let quote_token;
let quote_spot_price;
let quote_cart_total;

let quote_date;
let quote_token_contract;
let quote_token_decimals;
let quote_token_denomination; //wei
let quote_dest;
let quote_token_denomination_converted; //eth

let quote_loading_detail_text = "";

onMount(async () => {
    LOADING.setLoading(true, "Loading store");
    pushNotify("info", "Supercartd", "Welcome! This is a technical demo", 5000);
    await validate_setup().catch(ex => {
        alert(ex)
        throw ex;
    })
    await load_checkout();
    await load_cart();
    LOADING.setLoading(false, "");    
});

async function validate_setup(){
    if(!cid || cid.length < 10){
        alert('sorry this page cannot be loaded')
        location.href = "/";
        return false;
    }
    const ok = await $auth.actor.getCheckoutStatus(cid).then(x => {
        //console.log("checkout enabled: " + x)
        CHECKOUT_ENABLED = x;
    }).catch(ex => {
        alert("problem establishing connection to the store")
        throw ex;
    })
};

async function load_checkout(){
    const loaded_sv = await $auth.actor.getCheckoutStoreView(cid).then(x => {
        //console.log(x);
        if(x.status == 200){
            let sv = x.data[0];
            //console.log(sv)
            store_view = sv["merchant"];
            product_catalog = sv["products"][0] || [];
            //console.log(product_catalog)
            checkout_name = store_view["name"]          
        }else{
            alert("problem establishing connection to the store")
            throw Error;
        }
    })
}

async function load_cart(){    
    if($shoppingCart.length > 0){
        //console.log("HI THERE");
        document.getElementById("checkout-footer").style.display = 'block';3
        calculateTotal();
    }
}

async function load_payment_options(sc_chain_name){
    //console.log('load_payment_options')
    if(!cid || !sc_chain_name){
        console.log("Checkout not ready" + sc_chain_name)        
        return false;
    }
    //console.log("LOADING PAYMENTS FOR " + sc_chain_name)
    //console.log("FETCHHING load_payment_options for : " + sc_chain_name);
    const op = await $auth.actor.getCheckoutPaymentOptions(cid, sc_chain_name).then(x => {
        //console.log(x);
        if(x.status == 200){
            let options = x.data[0];        
            payment_options = options;
            return true;
        }else{
            //console.log(x.status_text)  
            if(x.error_text && x.error_text.length > 0){
                var msg = x.error_text[0];
                //alert(msg);
                pushNotify("error", "Payments", msg);
                document.getElementById("po_busy")?.removeAttribute("aria-busy");
                document.getElementById("po_busy").innerHTML = "No payment options found for chain";                
                return false;
            }
            //alert("problem establishing connection to the store")
            throw new Error("Problems fetching payments for chain")
        }        
    })
    return op;
}

function addItem(item){
    //console.log(item)
    if($shoppingCart.length >= MAX_CART_ITEMS){
        pushNotify("warning", "Cart warning", "Max cart items reached");
        //alert("Max items reached")
        return;
    }
    shoppingCart.addProduct(item);
    document.getElementById("checkout-footer").style.display = 'block';
    calculateTotal();
    var sku = item.sku ?? "Item"    
    pushNotify("success", "Cart", sku + " was added");
}

function displayImage(url){     
    const place_holders = ["/images/cart1.png", "/images/cart2.png"]
    if(!url || url.length  < 6){
        const randomIndex = Math.floor(Math.random() * place_holders.length);
        return place_holders[randomIndex];        
    }
    const isUrlAbsolute = (url) => (url.indexOf('://') > 0 || url.indexOf('//') === 0);    
    return stripHtmlTags(url); //todo
}

function calculateTotal(){
    //console.log(shoppingCart)    
    var details = shoppingCart.details();
    cart_sub_total = details["sub_total"];
    cart_tax_total = details["tax_total"]
    cart_total = details["total"];
}

function isValidEvmAddress(addr){
    //console.log('isValidEvmAddress ' + addr);
    if(!addr || addr == "" || addr == undefined) return false;
    var thing =  Web3.utils.isAddress(addr);    
    //console.log('isValidEvmAddress ' + thing);
    return thing;
}

function loadStep2WalletConnectors(){
    //console.log("ok opening connection dialog")
    document.getElementById("step2").style.display = "block"
    document.getElementById("step1").style.display = "none";
    document.getElementById("step3").style.display = "none";
    document.getElementById("step4").style.display = "none";
    document.getElementById("clear_cart").style.display = "none";

    document.querySelectorAll(".add-cart-button").forEach(x => {
        x.style.display = "None";
    })
}

// METAMASK
async function connectMetaMask(){
    if (window.ethereum && typeof(window.ethereum) !== "undefined") {
        ACTIVE_WALLET_CHAIN_ID = window.ethereum?.chainId;
        
        var mmClient = new MetaMask(1)        
        var is_unlocked = await mmClient.isUnlocked();
        //console.log("Is UNlocked? " + is_unlocked);

        await mmClient.onInit();
        ACTIVE_WALLET_PROVIDER_ID = WalletProvider.META_MASK;

        const acc = await mmClient.getAccount();
        if(acc){
            //console.log(acc)            
            let p = await mmClient.personalSign().then(z => {
                if(z != true){
                    //alert("user rejected request")
                    pushNotify("warning", "MetaMask", "User rejected the request", 3000);                    
                    return false;
                }
                var isvalid = isValidEvmAddress(mmClient.active_wallet);
                if(!isvalid){
                    document.getElementById('connection_status').innerHTML = "Meta Mask - No Access ";
                    return;
                }                
                ACTIVE_WALLET = mmClient.active_wallet;
                loadStep3PaymentOptions();
                //console.log("Verified mm with active wallet:  " + ACTIVE_WALLET)
            });            
        }
    }else{
        //alert("no Meta mask found");
        pushNotify("error", "MetaMask", "No MetaMask (browser) found");
        return false;    
    }
}

// PLUG WALLET
async function connectPlug(){
    // PLUG    
    if (window.ic && window.ic.plug){
        ACTIVE_WALLET_CHAIN_ID = "Internet Computer";
        const plugClient = new PlugWallet(1)        
        plugClient.onInit();

        var ok = await plugClient.login();        
        if(!ok || ok != true){
            //alert("user rejected request")    
            pushNotify("warning", "Plug Wallet", "User rejected the request");
            return false;
        }
        //console.log("OK RESULT " + ok);
        ACTIVE_WALLET_PROVIDER_ID = WalletProvider.PLUG_WALLET;
        ACTIVE_WALLET_CHAIN_ID = plugClient.chainId();
        ACTIVE_WALLET = plugClient.active_wallet;
   
        var can_load = loadStep3PaymentOptions();
        if(!can_load){
            alert("not ready for loading")
            return false;
        }
        return true;

    }else{
        console.log("no plug wallet found")
        //alert("no plug wallet found");
        pushNotify("error", "Plug Wallet", "No Plug Wallet (browser) found");
        return false;      
    }
}

async function connectPhantom(){
    ACTIVE_WALLET_CHAIN_ID = "sol_mainnet";
    const phantomClient = new PhantomWallet(1)        
    phantomClient.onInit();   
    
    const ok = await phantomClient.login().then(x => {
        ACTIVE_WALLET_PROVIDER_ID = WalletProvider.PHANTOM_WALLET;
        if(!x || x != true){
            //alert("user rejected request")
            pushNotify("warning", "Phantom Wallet", "User rejected the request");
            return false;
        }
        ACTIVE_WALLET = phantomClient.active_wallet;
        var can_load = loadStep3PaymentOptions();
        if(!can_load){
            alert("not ready for loading")
            return false;
        }
        return true;
    }).catch(ex =>{
        console.log(ex)
        throw ex;
    })  
}

async function connectWalletConnect(){
    throw new Error("not implemented");
    
    ACTIVE_WALLET_CHAIN_ID = "";

    const wcClient = new WalletConnect(1)        
    
    await wcClient.onInit();
    
    const ok = await wcClient.login().then(x => {
        ACTIVE_WALLET_PROVIDER_ID = WalletProvider.WALLET_CONNECT;
        if(!x || x != true){
            //alert("user rejected request")
            pushNotify("warning", "Wallet Connect", "User rejected the request");
            return false;
        }
        ACTIVE_WALLET = wcClient.active_wallet;
        var can_load = loadStep3PaymentOptions();
        if(!can_load){
            alert("not ready for loading")
            return false;
        }
        return true;
    }).catch(ex =>{
        console.log(ex)
        throw ex;
    })  
}





function loadStep3PaymentOptions(){
    //console.log("fetching payment details for chain " + ACTIVE_WALLET_CHAIN_ID)
    if(!ACTIVE_WALLET_CHAIN_ID){
        alert("Problem loading the correct chain")        
        return false;
    }
    document.getElementById("step2").style.display = 'none';    
    document.getElementById("step3").style.display = 'block';
    document.getElementById("step4").style.display = 'block';
    let translated_chain_name = ChainIdToTokenChain(ACTIVE_WALLET_CHAIN_ID)
    if(!translated_chain_name){
        alert("Problem translating the selected chain to scd")
        return false;
    }
    //fetch options
    const stuff = load_payment_options(translated_chain_name);
    if(stuff == false){
        //alert("problem loading the options for this chain..")
        pushNotify("error", "Checkout", "No payment options found for this chain");
        return false;
    }  

    return true;   
}

function getPaymentQuote(event, dest){    
    const selectedValue = event.target.value;
    //console.log('Selected value:', selectedValue);
    //console.log('Selected chain:', ACTIVE_WALLET_CHAIN_ID);
    //console.log('Selected provider:', ACTIVE_WALLET_PROVIDER_ID);    
    //console.log('Selected provider:', ACTIVE_WALLET);
    if(!selectedValue || !ACTIVE_WALLET_CHAIN_ID || !ACTIVE_WALLET_PROVIDER_ID || !ACTIVE_WALLET){
        alert("sorry this cart is not setup correctly. please reload the page")
        return false;
    }

    toggle_quote_buttons(true);
    document.getElementById("payment_quote_detail").style.display = 'none';    

    let sc_chain = ChainIdToTokenChain(ACTIVE_WALLET_CHAIN_ID);
    if(!sc_chain || !cid){
        alert("this cart cannot be priced")
        return false;
    }

    //console.log(selectedValue)    
    let sc_token = selectedValue; //slug or currency?
    ACTIVE_TOKEN = sc_token;
    //let token = "eth";
    //let chain = "eth_mainnet"

    let cart_items = [];
    $shoppingCart.forEach(x => {        
        var item = {
            "sku": x["sku"],
            "qty": 1,
            "price": x["price"],
            "tax1rate": x["tax1rate"],
            "tax2rate": x["tax2rate"]
        }
        cart_items.push(item);
    });

    let cart = {
        "cid": cid,
        "created_at": getTimestampEpoch(),
        "updated_at": getTimestampEpoch(),
        "currency": "USD",
        "active_wallet": ACTIVE_WALLET,
        "active_chain": sc_chain,
        "shipping_total": 0.00,
        "items" : cart_items
    }
    //console.log(cart)
    
    quote_loading_detail_text = "fetching latest quote ... ";
    document.getElementById("payment_quote").setAttribute("aria-busy", "true");    
    document.getElementById("payment_quote_detail_cancel").setAttribute("aria-busy", "true");    

    const quote = $auth.actor.createQuoteForCart(cid, sc_token, sc_chain, cart).then(x => {
        toggle_quote_buttons(false);
        quote_loading_detail_text = "";
        document.getElementById("payment_quote").setAttribute("aria-busy", "false");
        document.getElementById("payment_quote_detail_cancel").setAttribute("aria-busy", "false");

        if(x.status != 200 || !x["data"] || x["data"].length == 0){            
            alert("There was a problem fetching a quote...");
            return;
        }        

        var data = x["data"][0][0];
        //console.log(data);
        quote_token = data["token"]["name"];
        quote_spot_price = data["spot_price_per_unit"];
        quote_cart_total = data["grand_total"];
        quote_token_denomination = data["token_denomination"];
        quote_date = data["updated_at"];
        quote_token_contract = data["token"]["contract"];
        quote_token_decimals = data["token"]["decimals"];        
        quote_dest = dest;

        pushNotify("info", "Cart Engine", "Cart expires in 5 minutes");

        document.getElementById("payment_quote_detail").style.display = "block";
        document.querySelector(".connection_status").innerHTML = "";
        
    }).catch(ex =>{
        alert("There was a problem fetching a quote...");
        pushNotify("error", "Cart Engine", "There was a problem fetching a quote try another method");
        toggle_quote_buttons(false);
        document.getElementById("payment_quote").setAttribute("aria-busy", "false");
        document.getElementById("payment_quote_detail_cancel").setAttribute("aria-busy", "false");
        //document.getElementById("payment_quote_detail_cancel").style.display = "block";        
        return false;        
    });
    
}

// const WalletProvider = {
//   WALLET_CONNECT: 1,
//   META_MASK: 2,
//   INTERNET_IDENTITY: 3,
//   PLUG_WALLET: 4,
//   PHANTOM_WALLET: 5
// }
async function proposeTransaction(){    
    if(!quote_dest || !ACTIVE_WALLET || !ACTIVE_WALLET_CHAIN_ID || !quote_token_denomination){
        console.log("Invalid transaction parameters")
        alert("There was a problem creating the transaction")
        return;
    }
    document.querySelector(".connection_status").innerHTML = "Destination: " + ellipsis(quote_dest, 10);
    
    let manager = new TransactionProvider(ACTIVE_WALLET_CHAIN_ID);
    manager.active_wallet = ACTIVE_WALLET;
    
    var from = ACTIVE_WALLET;    
    var to = quote_dest;
    var amt = quote_token_denomination;
    //console.log("quote_token_denomination " + quote_token_denomination);
    var token_contract = quote_token_contract;
   
    if(from.toLowerCase() == to.toLowerCase()){
        //alert("You cannot send tokens to yourself")
        pushNotify("error", "Transaction", "You cannot send tokens to yourself")
        document.querySelector(".connection_status").innerHTML = "You cannot send tokens to yourself";
        return;
    }    
    
    LOADING.setLoading(true, "Awaiting client transaction ... ");
    const tx = await manager.proposeTransaction(ACTIVE_WALLET_PROVIDER_ID, from, to, amt, token_contract).then(x => {
        //console.log("transaction sent.. tx: ")
        //console.log(x)
        return x;
    }).catch(ex => {
        console.log(ex);
        document.querySelector(".connection_status").innerHTML = ex?.message;        
        pushNotify("error", "Transaction Error", ex?.message)
        //pushNotify("error", "Not Implemented", "Coming soon")
        LOADING.setLoading(false, "");
        throw ex;
    });
    console.log("final proposeTransaction result: " + JSON.stringify(tx));
    if(!tx || !tx.transactionHash){
        //alert("There was a problem creating the transaction")
        pushNotify("error", "Transaction", "There was a problem creating the transaction")
        LOADING.setLoading(false, "");
        return;
    }

    await finalizeTransaction(tx);
}

async function finalizeTransaction(tx){
    //console.log("finalizeTransaction: " + tx);
    let chain = ChainIdToTokenChain(ACTIVE_WALLET_CHAIN_ID)
    let token = ACTIVE_TOKEN;
    let tx_hash = tx.transactionHash.toString();
    let source_wallet = ACTIVE_WALLET;
    let dest_wallet = quote_dest;
    let amt = quote_cart_total;
    let gas = tx.cumulativeGasUsed?.toString() || "";
    let block_height = tx.blockNumber.toString() || "";

    let cart_items = [];
    $shoppingCart.forEach(x => {        
        var item = {
            "sku": x["sku"],
            "qty": 1,
            "price": x["price"],
            "tax1rate": x["tax1rate"],
            "tax2rate": x["tax2rate"]
        }
        cart_items.push(item);
    });

    let cart = {
        "cid": cid,
        "created_at": getTimestampEpoch(),
        "updated_at": getTimestampEpoch(),
        "currency": "USD",
        "active_wallet": source_wallet,
        "active_chain": chain,
        "shipping_total": 0.00,
        "items" : cart_items
    }

    LOADING.setLoading(true, "Success! Generating receipt");

    const receipt = await $auth.actor.createOrder(cid, token, chain, block_height, tx_hash, cart, source_wallet, dest_wallet, amt, gas).then(x => {
        // console.log("ORDER CREATED")
        // console.log(x);
        return x;
    }).catch(ex =>{
        //alert("There was a problem creating this order!")
        console.log(ex);
        pushNotify("error", "Order", "Error creating this order")
        LOADING.setLoading(false, "");
        throw new Error("Problem creating supercart order");
    });

    //console.log("this is the receipt: " + receipt);
    //LOADING.setLoading(false, "");
    if(receipt.status != 200){
        //alert("problem loading the receipt...")
        pushNotify("error", "Order", "Error loading the receipt ... ")
        LOADING.setLoading(false, "");
        return;
    }
    var r = receipt.data[0];
    var receipt_id = r["rid"];
    //redirect to receipt page 
    pushNotify("success", "Receipt", "Redirecting you to your receipt")
    var url = "/receipt/" + receipt_id;
    location.href = url;
}


function toggle_quote_buttons(is_disabled){
    document.querySelectorAll(".selected_payment").forEach(r => {
        r.disabled = is_disabled;
    });
}


function reset(){
    //console.log("im resetting")
    ACTIVE_WALLET_PROVIDER_ID = null;
    ACTIVE_WALLET_CHAIN_ID = null;
    ACTIVE_WALLET = null;
    payment_options = [];

    document.getElementById("step1").style.display = 'block';
    document.getElementById("step2").style.display = 'none';
    document.getElementById("step3").style.display = 'none'
    document.getElementById("step4").style.display = 'none';

    document.getElementById("clear_cart").style.display = "block";

    document.getElementById("payment_quote_detail").style.display = 'none';

    document.getElementById('connection_status').innerHTML = "";
    document.getElementById('chain_status').innerHTML = "";
    quote_loading_detail_text = "";
    document.querySelectorAll(".connection_status").forEach(x => {
        x.innerHTML = "";
    });   
    document.querySelectorAll(".add-cart-button").forEach(x => {
        x.style.display = "block";
    })
    
}

</script>

<header class="container-fluid header-main" id="nav_header">   
    <h1 style="margin-left: -20px;">{checkout_name}</h1>
</header>
<main>
    {#if (!CHECKOUT_ENABLED)}    
        {#if (IS_LOADING) }

        <div class="pico-color-orange-500">
           ...loading
        </div>

        {:else}

        <div class="pico-color-red-500">
            SORRY CHECKOUT IS CLOSED
        </div>        

        {/if}
        
    {:else}
        <div class="pico-color-green-500">
            CHECKOUT OPEN        
        </div>        
        <article>
            <header></header>
            {#if product_catalog.length > 0}
                {#each product_catalog as entry}

                    {@const product = entry}
                    {@const pid = entry["pid"]}
                    {@const name = entry["name"]}                    
                    {@const sku = entry["sku"]}
                    {@const price = entry["price"]}
                    {@const updated_at = entry["updated_at"]}
                    {@const is_enabled = entry["is_enabled"]}        
                    
                    {@const description = entry["description"]}
                    {@const description2 = entry["description2"]}

                    {@const image_url = entry["image_url"][0]}
                    {@const sku_title = sku + " " + name}

                    {#if (is_enabled)}
                        <div class="grid">                            
                            <div>                                
                                <div class="detail-large"><b>{@html name}</b></div>
                                <div class="detail-line">
                                    {description}
                                </div>                                
                                <img src={displayImage(image_url)} alt={sku} title={sku_title}
                                class="product-thumb" />
                                <div class="detail-line detail-right detail-large ">
                                   <b> ${price.toFixed(2)}</b>
                                </div>
                                <div class="detail-right">
                                    <button on:click={() => addItem(product)} class="secondary add-cart-button">Add to Cart</button>                                    
                                </div>
                            </div>                         
                        </div>
                        <div style="height: 20px; background-color: none;"></div>
                    {/if}
                    
                {/each}
            {/if}
            
            <footer id="checkout-footer" style="display: none;">
                {#each $shoppingCart as cart_item}
                    <p>{cart_item.name} - {cart_item.sku} - {cart_item.price}</p>
                <hr />                
                {/each}      
                <div>
                    {#if ($shoppingCart.length > 0)}
                        <div class="detail-center detail-large">
                            <div class="detail-right">
                                Sub Total: {cart_sub_total}
                            </div>
                            {#if (cart_tax_total > 0)}
                            <div class="detail-right">
                                Tax: {cart_tax_total}
                            </div>
                            {/if}                                 
                               
                            <div class="detail-right detail-large">
                                <b>Total: ${cart_total}</b>
                            </div>
                        </div>
                        <!-- svelte-ignore a11y-invalid-attribute -->
                        <a id="clear_cart" href="#" on:click={() => shoppingCart.reset()}>Clear Cart</a>                    
                        <hr>
                        <div id="step1" class="detail-center" >
                            <button on:click={() => loadStep2WalletConnectors()}>PROCEED TO CHECKOUT</button>
                        </div>
                    {/if}
                </div>        
                
                <div id="step2" class="step2">
                    <h2>Connect your wallet</h2>
                                  
                        <!-- svelte-ignore a11y-invalid-attribute -->
                        <p><img src="/images/wallets/metamask_wallet_small.png" alt="" title="MetaMask Wallet" class="wallet-icon"/>
                            <a href="#" on:click={() => connectMetaMask()}  title="meta mask" alt="" id="btnMetaMask" >Meta Mask</a></p>
                        <!-- svelte-ignore a11y-invalid-attribute -->
                        <p><img src="/images/wallets/plug_wallet_small.png" alt="" title="Plug Wallet" class="wallet-icon"/>
                            <a href="#" on:click={() => connectPlug()} title="plug" alt="">Plug Wallet</a></p>
                        <!-- svelte-ignore a11y-invalid-attribute -->
                        <p><img src="/images/wallets/phantom_wallet_small.png" alt="Phantom Wallet" title="" class="wallet-icon"/>
                            <a href="#" on:click={() => connectPhantom()} title="phantom" alt="">Phantom Wallet</a></p>
                        <!-- svelte-ignore a11y-invalid-attribute -->
                        <!-- <p><img src="/images/wallets/wallet_connect.png" alt="" title="Wallet Connect" class="wallet-icon"/>
                            <a href="#" on:click={() => connectWalletConnect()} title="wallet connect" alt="">Wallet Connect</a></p> -->
                   
                </div>
                <div id="step3" class="step3">

                    <article>                
                        <div>Provider: <b>{WalletProviderToString(ACTIVE_WALLET_PROVIDER_ID)}</b></div>                
                        <div>status: <span id="connection_status_color"><code id="connection_status"></code></span></div>                
                        <div>chain: <span id="chain_status">{ACTIVE_WALLET_CHAIN_ID}</span></div>
                    </article>

                </div>
                <div id="step4" class="step4">                    
                    <h2>Payments for <code class="pico-color-green-500">{ChainIdToTokenChain(ACTIVE_WALLET_CHAIN_ID)}</code></h2>
                    <fieldset>
                        <legend>Select payment option:</legend>
                        {#if (payment_options.length > 0)}
                            {#each payment_options as entry, i}
                                {@const yo = entry["dest"]}
                                {@const slug = key2val(entry["token_type"])}
                                {@const image_url = "/images/tokens/" + slug + ".png".toLowerCase() }                               
                                <label>
                                    <input type="radio" name="selected_payment" on:change={(event, dest) => getPaymentQuote(event, yo)} value={slug} class="selected_payment"/>
                                    <img src="{image_url}" alt="" class="token-icon" /> {slug.toUpperCase()}
                                </label>
                            {/each}
                        {:else}
                            <!-- <p>No payment options for this <code>chain</code></p> -->
                            <div aria-busy="true" id="po_busy">loading options for: <code>{ACTIVE_WALLET_CHAIN_ID}</code> </div>
                        {/if}
                    </fieldset>
                    <div id="payment_quote">
                        {quote_loading_detail_text}
                        <div id="payment_quote_detail" class="payment_quote_detail">
                          <article>
                            <h2>Cart Quote:</h2>
                            <p>Token: <code class="pico-color-green-500">{quote_token}</code></p>
                            <p>Spot Price: <code class="pico-color-green-500">{quote_spot_price}</code></p>

                            <p>Contract: <code class="pico-color-green-500">{quote_token_contract == "" ? "Native" : quote_token_contract}</code></p>
                            <p>Decimals: <code class="pico-color-green-500">{quote_token_decimals}</code></p>
                            
                            <p>Token Total: <code class="pico-color-green-250"><b>{quote_token_denomination}</b></code> (wei)</p>
                            <p style="font-size: larger;">Cart Total: <code class="pico-color-green-250"><b>{quote_cart_total}</b></code></p>

                            <!-- <p>Conversion: <code>{quote_conversion}</code></p> -->
                            <p>Date: <code>{timeAgoFromSecondEpoch(quote_date)}</code></p>
                            
                            <p><code class="connection_status"></code></p>
                            <br>
                            <div class="payment_quote_detail_control">
                                <button class="" on:click={proposeTransaction}>CONFIRM PAYMENT</button>
                            </div>
                            
                          </article>
                        </div>
                    </div>
                    <hr>

                    <div class="detail-right">                            
                        &nbsp;<button id="payment_quote_detail_cancel" class="secondary payment-cancel" on:click={reset}>Cancel</button>
                    </div>

                </div>           
               
            </footer>
            
          </article>
    {/if}
</main>
<footer class="footer-bottom">
   Supercart 2024
   <br>
   Technical Demo
</footer>
<style>
    .detail-line{
        margin-top: 10px;
        margin-bottom: 10px;
    }
    
    .product-thumb{
        border: none 2px black;     
        width: 70%;
        height: 70%;   
    }

    .detail-right{
        border: none 1px blue;
        text-align: right;
    }
    .add-cart-button{        
        margin-left: auto;
        margin-right: 0;
        
    }
    .detail-center{
        text-align: center;
    }
    .detail-large{
        font-size: larger;
        font-weight: bolder;
    }
    .step2{
        display: none;
        border: none 1px red;
    }
    .step3{
        display: none;
        border: none 1px green;
    }
    .step4{
        display: none;
        border: blue 1px green;
    }

    .token-icon{
      width: 32px;
      height: 32px;
      vertical-align:auto;
    }
    .wallet-icon{
      width: 32px;
      height: 32px;
      vertical-align:auto;
    }

  .payment_quote_detail{
    padding: 5 5 5 5;
    border: none 2px lawngreen;
    display: none;
  }
  .payment_quote_detail_control{
    text-align: center;
    font-weight: bold;
  }
  .footer-bottom{
    text-align: center;
  }

</style>