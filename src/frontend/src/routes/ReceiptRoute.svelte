<script>
import { onMount, onDestroy } from "svelte";
import { auth, user, token } from "../store/auth.js";
import { Link, navigate } from "svelte-routing";
import { timeAgoFromEpoch, key2val, get_blockscan_url } from "../store/utils.js"
import { LOADING, removeBusy } from "../store/loader.js";   
    
export let rid; //receipt id
let cid;
let receipt;

let IS_LOADING;
const unsubscribe = LOADING.subscribe((value) => {
    IS_LOADING = value["status"] == "IDLE" ? false : true;
});
onDestroy(unsubscribe);

onMount(async () => {      
    //await bind_merchant();
    LOADING.setLoading(true, "");
    if(!rid){
        alert("Invalid receipt")
        return;
    }
    await get_receipt();   
    LOADING.setLoading(false, "");    
});

async function get_receipt(){
    if(!rid){
        console.log("invalid rid cid ")
        return;
    }
    const thing = $auth.actor.getReceiptByReceiptId(rid).then(x =>{        
        let r = x[0];                
        receipt = r;            
        //console.log(r)        
        cid = receipt["cid"];            
    }).catch(ex => {
        alert("sorry problem loading your receipt")        
        throw ex;
    })
}    

function unwrapKey2Val(thing){
    if(!thing) return "NA"
    return key2val(thing);
}

function getBlockScanUrl(chain, tx, height){
    let sc_chain = unwrapKey2Val(chain)
    var t = {"sc_chain": sc_chain, "tx_hash" : tx, "block_height": height};
    //console.log(t);
    var url = get_blockscan_url(t, false);
    //console.log(url)        
    return url;
} 

function returnToCheckout(){    
    var url = "/checkout/" + cid;
    navigate(url, true);
}

</script>

<nav aria-label="breadcrumb">
    <h1>Order Receipt</h1>
</nav>

{#if (IS_LOADING)}
    <h1> loading receipt ... </h1>
{:else}

<article>    

    <p>Receipt <code>{rid}</code></p>
    <p>Created <code>{timeAgoFromEpoch(receipt?.created_at)}</code></p> 
    <p>Chain <code class="pico-color-green-250">{unwrapKey2Val(receipt?.chain)}</code></p>      
    <p>Transaction Hash <code>{@html getBlockScanUrl(receipt?.chain, receipt?.onchain_tx, receipt?.block_height)}</code></p>
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
    
        <!-- <div>
            <h4>Shipping Details</h4>
            <p>Name <code>{receipt?.first_name}</code></p>
            <p>Email <code>{receipt?.email}</code></p>
            <p>Address 1 <code>{receipt?.shipping_address1}</code></p>
            <p>Address 2 <code>{receipt?.shipping_address2}</code></p>
            <p>City <code>{receipt?.shipping_city}</code></p>
            <p>State <code>{receipt?.shipping_state}</code></p>
            <p>Postal Code <code>{receipt?.shipping_zip}</code></p>
            <p>Country <code>{receipt?.shipping_country}</code></p>
        </div> -->
        
        
    
    </div> 

    <hr>
    <br>
    <div class="grid detail-center">
        <!-- <div><button >email me</button> </div>
        <div><button> sms me</button> </div> -->
        <div><button class="secondary" on:click={returnToCheckout}>Return to Checkout</button></div>
    </div>


    </article>



{/if}
    
    
<style>   
.detail-center{
    text-align: center;
}

</style>