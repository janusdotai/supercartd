<script>
import { onMount, afterUpdate } from "svelte";
import { auth, user, token } from "../store/auth.js";
import { Link, navigate } from "svelte-routing";
import { getTimestampEpoch, timeAgoFromEpoch, ellipsis, first, flatten, key2val, get_blockscan_url } from "../store/utils.js"
import { LOADING, removeBusy } from "../store/loader.js";


export let rid; //receipt id
let cid;
let receipt;
let receipt_items = [];
let product_catalog = [];

var host = window.location.protocol + "//" + window.location.host;

let public_receipt_url = host + "/receipt/" + rid;

onMount(async () => {      
    await bind_merchant();      
});

async function bind_merchant(){        
    LOADING.setLoading(true, "");      
    let merchant_response = await $auth.actor.getMerchant().then(m => {
        if(m.status != 200){
            alert("problem loading merchant...please relogin")
            LOADING.setLoading(false, "");
            navigate("/");
            return;
        }
        let data = m["data"][0]        
        cid = data["cid"]
        return;
    });        

    await bind_products();
    await get_receipt();
    LOADING.setLoading(false, "");
}

async function get_receipt(){
    if(!cid || !rid){
        console.log("invalid rid cid ")
        return;
    }
    const thing = $auth.actor.getReceipt(cid, rid).then(x =>{        
        let r = x[0];                
        receipt = r;                    
        receipt_items = receipt["items"]        
    })
}

async function bind_products(){    
    let stuff = await $auth.actor.getMerchantProducts(cid).then(p => {        
        let data = p["data"] || [];            
        var catalog = data[0];        
        let tmp = []
        catalog.forEach(x => {
            let id = x[0];
            let product = x[1];            
            tmp.push(product);
        })             
        product_catalog = tmp;        
    });
}

function goBack(){
    navigate("/store/orders", false);
}

function tryGetImageFromSku(sku){
    const match = product_catalog.find(x => x.sku == sku)    
    if(match){
        let url = match["image_url"][0]        
        return url;
    }
    return "";
}

function unwrapKey2Val(thing){
    if(!thing) return "NA"
    return key2val(thing);
}

function getBlockScanUrl(chain, tx, height){
    let sc_chain = unwrapKey2Val(chain)
    var t = {"sc_chain": sc_chain, "tx_hash" : tx, "block_height": height};    
    var url = get_blockscan_url(t, false);    
    return url;
} 

function getImageUrl(image_url){
    const place_holders = ["/images/cart1.png", "/images/cart2.png"]
    if(!image_url || image_url.length  < 6){
        const randomIndex = Math.floor(Math.random() * place_holders.length);
        return place_holders[randomIndex];        
    }
    return image_url;
}

</script>

<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>
        <Link to="/store/orders" title="Orders">Orders</Link>
      </li>
      <li>Receipt</li>
    </ul>
</nav>
<section>
    <h4>Receipt</h4>
</section>

<section>


  <p>ID <code>{rid}</code></p>
  <p>URL <code>{public_receipt_url}</code></p>  
  <p>Created <code>{timeAgoFromEpoch(receipt?.created_at)}</code></p> 
  <p>Chain <code class="pico-color-green-250">{unwrapKey2Val(receipt?.chain)}</code></p>  
  <p>Transaction <code>{@html getBlockScanUrl(receipt?.chain, receipt?.onchain_tx, receipt?.block_height)}</code></p>    
  <hr>

  <div class="grid">

    <div>
        <h4>Totals</h4>
        <p>Paid With <code class="pico-color-green-250">{unwrapKey2Val(receipt?.token_currency).toUpperCase()}</code></p>
        <p>Currency <code>{unwrapKey2Val(receipt?.currency).toUpperCase()}</code></p>
        <p>Sub Total <code>${receipt?.sub_total.toFixed(2)}</code></p>
        <p>Shipping Total <code>${receipt?.shipping_total.toFixed(2)}</code></p>
        <p>Tax <code>${receipt?.tax_total.toFixed(2)}</code></p>
        <p>Fees <code>${receipt?.additional_fee.toFixed(2)}</code></p>
        <p><b>Grand Total <code class="pico-color-green-250">${receipt?.total.toFixed(2)}</code></b></p>
    </div>

    <div>
        <h4>Shipping Details</h4>
        <p>Name <code>{receipt?.first_name}</code></p>
        <p>Email <code>{receipt?.email}</code></p>
        <p>Address 1 <code>{receipt?.shipping_address1}</code></p>
        <p>Address 2 <code>{receipt?.shipping_address2}</code></p>
        <p>City <code>{receipt?.shipping_city}</code></p>
        <p>State <code>{receipt?.shipping_state}</code></p>
        <p>Postal Code <code>{receipt?.shipping_zip}</code></p>
        <p>Country <code>{receipt?.shipping_country}</code></p>
    </div>
    
  
</div>
<hr>    
    <h4>Items</h4>
    <table>
        <thead>
            <tr>                  
            <th scope="col">Sku</th>
            <th scope="col">Qty</th>                    
            <th scope="col">Price</th>                          
            <th scope="col">Tax1</th>                    
            <th scope="col">Tax2</th>
            <th scope="col"></th>
            </tr>
        </thead>
        <tbody>
            {#if (receipt_items.length > 0)}
                {#each receipt_items as entry}        
                {@const sku = entry["sku"]}
                {@const price = entry["price"]}
                {@const qty = entry["qty"]}
                {@const tax1 = entry["tax1rate"]}
                {@const tax2 = entry["tax2rate"]}
                {@const image_url = tryGetImageFromSku(sku)}
                <tr>
                    <td>
                        {sku}
                    </td>
                    <td>
                        {qty}
                    </td>
                    <td>
                        {price.toFixed(2)}
                    </td>
                    <td>
                        {tax1}
                    </td>
                    <td>
                        {tax2}
                    </td>
                    <td>
                        <img src={getImageUrl(image_url)} alt="" class="product-thumb">
                    </td>
                </tr>
                {/each}
            {/if}
            
        </tbody>
    </table>    


<br>
<button  class="secondary" on:click|preventDefault={goBack}>Back</button>
</section>

<style>
    .product-thumb{
        border: none 2px black;     
        width: 64px;
        height: 64px;   
    }

</style>