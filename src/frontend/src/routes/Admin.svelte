
<script>
    import { onMount, afterUpdate } from "svelte";    
    import { Link, navigate } from "svelte-routing";
    import { auth, user, token, IS_PRODUCTION } from "../store/auth";    
    import { LOADING, removeBusy } from "../store/loader.js";
    import { getTimestampEpoch, timeAgoFromEpoch, pushNotify } from "../store/utils.js"   
    import { AuthClient } from "@dfinity/auth-client";

    /** @type {AuthClient} */
    let authClient;
    
    let cid;
    let current_principal_raw = null;
    let current_principal = "";
    let user_name = $user.name;
    let token_info = $token;   

    let product_catalog = [];

    let active_product_length = 0;
    let inactive_product_length = 0;

    let active_payment_settings = [];
    let checkout_orders = [];    
    let checkout_enabled = false;    

    let host = window.location.protocol + "//" + window.location.host;
    $: public_checkout_url = host + "/checkout/" + cid;

    $: CHECKOUT_READY = (checkout_enabled && active_product_length > 0 && active_payment_settings.length > 0 )    
   
    onMount(async () => {
        if($auth.loggedIn){            
            LOADING.setLoading(true, "loading admin ....")            
            try{
                let principal = await $auth.actor.whoami().then(x => {                    
                    current_principal_raw = x;
                    console.log("admin route principal : " + x.toString());
                    current_principal = x.toString();
                });
            }catch(error){
                console.log("FATAL ERROR ")
                console.log(error)                
                alert('There was an error and your session has timed out');
                //pushNotify("error", "Error", "Session timeout")
                location.href = "/";
            }
        }else{
            console.log("FAIL - auth.loggedIn is FALSE")
            alert('there was an error and your session has timed out');
            location.href = "/";
        }                
        LOADING.setLoading(false, "");
    });


    let getMerchantPromise = getMerchant();
    async function getMerchant(){
        let merchant_response = await $auth.actor.getMerchant();        
        if(merchant_response.status != 200){
            //let err = merchant_response?.error_text[0];            
            return;
        };
        
        let merchant = merchant_response["data"][0];        
        cid = merchant["cid"];        
        checkout_enabled = merchant["is_enabled"];
        await load_active_products();
        await get_active_settings_count();
        await get_latest_orders();
        return merchant;
    }


    async function load_active_products(){        
        let stuff = await $auth.actor.getMerchantProducts(cid).then(p => {            
            let data = p["data"] || [];
            const catalog = data[0].map(subarray => subarray[1]);
            const enabled_products = catalog.filter(x => x["is_enabled"] == true);
            active_product_length = enabled_products.length;
            inactive_product_length = catalog.length - active_product_length;            
            product_catalog = enabled_products;            
        }).catch(ex =>{
            pushNotify("error", "Error", "Failed to load products");
            console.log(ex);            
        });
    }

    async function signOut(){
        const client = authClient ?? (await AuthClient.create());
        await client.logout();        
        authClient = null;
        localStorage.clear();
        console.log("done you are logged out");
        window.location.href = "/";
    }

    async function get_active_settings_count(){
        let stuff = await $auth.actor.getPaymentSettings().then(p => {           
            active_payment_settings = p[0] || [];
        });
    }

    async function get_latest_orders(){        
        const orders = await $auth.actor.getOrders(cid).then(x => {            
            checkout_orders = x[0] || [];
        })
    }

    function generate_checkout_url(){
        return public_checkout_url;    
    }

    function navigate_to_public(){
        var url = generate_checkout_url();        
        window.open(url, "_blank");
        return;
    }   
    
    function startSellingShow(){
        document.getElementById("start_selling").style.display = "Block";
    }

</script>

<div>    
    <div class="checkout-status">
        {#if (CHECKOUT_READY)}
        <div>
            Checkout Ready: <code class="pico-color-green-250">{CHECKOUT_READY}</code>
        </div>
        <div class="view-site">            
            <!-- svelte-ignore a11y-invalid-attribute -->
            <p><a href="#" on:click|preventDefault={navigate_to_public} ><b>View Checkout</b></a></p>            
        </div>
        {:else}
        <div>
            Checkout Ready: <code class="pico-color-orange-250">{CHECKOUT_READY}</code>
        </div>
        {/if}        
    </div>

    <nav aria-label="breadcrumb">
        <ul>
          <li><a href="/">Home</a></li>          
          <li>Admin</li>
        </ul>
      </nav>
      
    <hgroup>
        <h2>Config</h2>               
    </hgroup>
   
    {#if current_principal !=""}        
        <article>
            <h3><em data-tooltip="Your principal login" data-placement="right">My Info</em></h3>
            <p>Principal: <code>{current_principal}</code></p>
            <p>User: <code>{user_name}</code></p>
            <p>Token: <code>{token_info} (testnet)</code></p>
            <p>Environment: <code>{IS_PRODUCTION ? "Live" : "Staging"}</code></p>
        </article>        
    {/if}    

    <article>
        <div><h3><em data-tooltip="Setup your store" data-placement="right">Settings</em> <span class="smaller"> - <Link to="/store/edit">edit</Link></span></h3></div>
        
        {#await getMerchantPromise}
            <p>...loading checkout</p>
        {:then checkout}        
            {#if (checkout != null)}                
                <p class="pico-color-black-500">Name: <code>{@html checkout.name}</code></p>                
                {#if (checkout.is_enabled === true)}
                    <p>Status: <b><code class="pico-color-green-250" >ENABLED</code></b></p>
                {:else}
                    <p>Status: <b><code class="pico-color-red-500">DISABLED</code></b></p>
                {/if}
                <p>Created: <code>{timeAgoFromEpoch(checkout.created_at)}</code></p>                
            {:else}
                <p class="pico-color-orange-500">No checkout found - edit to get started</p>                
            {/if}            
        {:catch error}            
            <p style="color: red">{error.message}</p>
        {/await}
      
        <p><Link to="/store/edit">Edit Checkout</Link></p>
        <p><Link to="/store/logs">View Logs</Link></p>           

    </article>

    {#if (cid)}
        <article>
            <h3><em data-tooltip="Create and edit products to sell" data-placement="right">Catalog</em> <span class="smaller"> - <Link to="/store/products">edit</Link></span></h3>
            <p>Active products: <code class="pico-color-green-250">{active_product_length}</code></p>  
            <p>Inactive products: <code class="pico-color-orange-250">{inactive_product_length}</code></p>       
            <p><Link to="/store/products">View Catalog</Link></p>
        </article>
    {/if}
    
    {#if (cid)}
        <article>       
            <div><h3><em data-tooltip="Configure your payments" data-placement="right">Payments</em> <span class="smaller"> - <Link to="/store/payments">edit</Link></span></h3></div>
            {#if (active_payment_settings.length > 0)}
                <p>Active: <code class="pico-color-green-250">{active_payment_settings.length}</code></p>
            {/if}
            <p><Link to="/store/payments">View Payments</Link></p>

        </article>   
    {/if}
    {#if (cid)}
        <article>       
            <div><h3><em data-tooltip="View your orders and receipts" data-placement="right">Orders</em></h3></div> 
            {#if (checkout_orders.length > 0)}
                <p>Total: <code class="pico-color-green-250">{checkout_orders.length}</code></p>
            {/if}
            <p><Link to="/store/orders">View Orders</Link></p>
        </article> 
    {/if}
    {#if (cid && CHECKOUT_READY)}
        <article>
        <h1><button on:click={startSellingShow}>Start Selling</button></h1>
            <section id="start_selling" class="start-selling">
                <article>            
                    <p>Your public checkout: <code class="public-url-code">{generate_checkout_url()}</code></p>
                    <p>QR for public checkout: <code>qr</code></p>            
                    <p>Script Tags for external integrations: </p>
                    <textarea></textarea>        
                    <div class="view-checkout">
                        <h4><b><a href={generate_checkout_url()} target="_blank" class="button">View Checkout</a></b></h4>                
                    </div>                        
                        
                </article>
            </section>
        </article> 
    {/if}
    <section>
        <div style="text-align: right;">
            <button on:click={signOut} class="secondary">Logout</button>
        </div>
    </section>
</div>

<style>
    .smaller{
        font-size: smaller;
    }
    .checkout-status{
        float: right; 
        border: none 1px blue; 
        margin-top: 10px;
    }

    .view-site{
        text-align: right;
        padding-right: 10px;
    }
    .start-selling{
        display: none;
    }
    .public-url-code{
        font-size: larger;
        padding: 1rem;
    }
    .view-checkout{
        text-align: center;
    }
</style>