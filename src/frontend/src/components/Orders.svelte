<script>
    import { Link, navigate } from "svelte-routing";
    import { onMount, afterUpdate } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { timeAgoFromSecondEpoch, ellipsis, key2val, get_blockscan_url, transformOrderHistory } from "../store/utils.js";
    import { LOADING, removeBusy } from "../store/loader.js";
    import AreaChart from "./charts/AreaChart.svelte";
    
    let cid;
    let checkout_orders = [];
    let checkout_receipts = [];    

    let chart;
    let chart_data_loaded;
    let chart_data_final = [];

    
    onMount(async () => {      
      await bind_merchant();      
    });

    async function bind_merchant(){        
        LOADING.setLoading(true, "");      
        let merchant_response = await $auth.actor.getMerchant().then(m => {
            let data = m["data"][0]            
            //console.log(m)
            //console.log(data)            
            cid = data["cid"]
            bind_receipts(cid).then(x =>{
                bind_orders(cid);
            });
        });        
    }    

    async function bind_orders(cid){
        //console.log("binding orders for id " + cid)
        const orders = await $auth.actor.getOrders(cid).then(x => {
            //console.log(x);
            checkout_orders = x[0] || [];            
            //chart_data_final = checkout_orders;
            chart_data_final = transformOrderHistory(checkout_orders);
            //console.log(chart_data_final);
            chart.update_chart(chart_data_final);            
            console.log("LOADED CHART")
        })
    }

    async function bind_receipts(cid){
        //console.log("binding receipts for id " + cid)
        const orders = await $auth.actor.getReceipts(cid).then(x => {            
            //console.log(x);
            checkout_receipts = x[0] || [];
            LOADING.setLoading(false, "");           
        })
    }
    
    function goBack(){
        navigate("/admin", false);
    }  

    function getBlockScanUrl(chain, tx, block_height){
        var t = {"sc_chain": chain, "tx_hash" : tx, "block_height": block_height};
        //console.log(t);
        var url = get_blockscan_url(t);
        //console.log(url)        
        return url;
    }   

    function getReceiptId(oid){
        //console.log(oid)
        var match = checkout_receipts.filter(x => x.oid == oid)
        if(match && match.length > 0){            
            let rid = match[0]["rid"]
            //console.log("receipt id : " + rid )
            return rid;
        }
        return "";
    }

    function viewReceipt(rid){
        if(!rid) return;
        //console.log(rid)
        let url = "/store/receipts/" + rid;
        navigate(url, false);        
    }

    
    
</script>

<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>Orders</li>
    </ul>
</nav>
<section>
    <h1>Orders</h1>
</section>
<section>   

    {#if (checkout_orders.length == 0)}        
        <section class="pico-color-red-500" id="checkout_warning">
            No Orders found.
        </section>        
    {:else}

        <div>
            <table>
                <thead>
                  <tr>                  
                    <th scope="col">Receipt</th>
                    <th scope="col">Total</th>                    
                    <th scope="col">Status</th>                          
                    <th scope="col">Updated</th>                    
                    <th scope="col">Chain</th>
                    <th scope="col">Height</th>
                    <th scope="col">Tx</th>
                  </tr>
                </thead>
            
                <tbody>
                {#if checkout_orders.length > 0}
                    {#each checkout_orders as entry}
                    <!-- { console.log(entry)} -->
                    {@const oid = entry["oid"]}
                    {@const tx = entry["onchain_tx"]}
                    {@const status = key2val(entry["status"])}
                    {@const updated_at = entry["updated_at"]}
                    {@const grand_total = entry["grand_total"]}
                    {@const chain = key2val(entry["chain"])}
                    {@const block_height = entry["block_height"]}
                    {@const blockscan_url = getBlockScanUrl(chain, tx, block_height)}
                    {@const rid = getReceiptId(oid)}
                    {@const chain_image_url = "/images/chains/" + chain + ".png"}
                    {@const is_testnet = chain.includes("testnet")}
                    <tr>
                        <!-- svelte-ignore a11y-invalid-attribute -->
                      <td><a href="#" on:click={viewReceipt(rid)}>{ellipsis(rid, 6)}</a></td>
                      <td>${grand_total.toFixed(2)}</td>           
                      <td>{status}</td>
                      <td>{timeAgoFromSecondEpoch(updated_at)}</td>
                      <td> <img src={chain_image_url} alt={chain} width="32" height="32" />                        
                        {#if (is_testnet)}
                            <span class="pico-color-yellow-500">{chain}</span>
                        {:else}
                            <span class="pico-color-green-500">{chain}</span>
                        {/if}                       

                    </td>
                      <td>{block_height}</td>
                      <td>{@html blockscan_url}</td>
                    </tr>        
                    {/each}
                  {/if}
                </tbody>
                {#if (checkout_orders.length == 0)}        
                <tfoot>
                    <tr>
                      <th scope="col" colspan=7 class="footer">Total: {checkout_orders.length}</th>
                    </tr>
                  </tfoot>
                {/if}
              </table>
              
        </div>
    {/if}    
</section> 
   
    <article>        
        <figure>   
            <AreaChart bind:this={chart} bind:data_loaded={chart_data_loaded}  />
            {#if (checkout_orders.length > 0)}        
                <figcaption>Sales</figcaption>
            {/if}
        </figure>
    </article>    

<hr>

<p>
    <button class="secondary" on:click={goBack}>Back</button>
</p>

<style>
    .footer{
        text-align: right;
        border: none 1px blue;
        padding-right: 10px;
    }
</style>