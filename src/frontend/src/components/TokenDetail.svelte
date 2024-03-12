
<script>
    import { onMount, afterUpdate } from "svelte";
    import { auth, user } from "../store/auth.js";
    import { Link } from "svelte-routing";
    import { LOADING, removeBusy } from "../store/loader.js";
    import { timeAgoFromSecondEpoch, transformTokenHistory, flatten, pushNotify } from "../store/utils.js";
    import LineChart from './charts/LineChart.svelte';

    export let id;
    $: selected_slug = id;
    $: token_history = [];
    let selected_token = null;

    let chart;
    let chart_data_loaded;
    let chart_data_final = [];
    let most_recent_twap = 0;

    let most_recent_quote = {};
    let selected_token_desc = "no description";
    let decimals = 0;
    let contract = "";
    let chains;    
    let icon_url = "na.png";

    onMount(async () => {          
        
        chart_data_loaded = false;
        
        await loadTokenDetails(selected_slug);
    });

    async function loadTokenDetails(selected_slug){
        console.log("loading details for " + selected_slug);

        const all_tokens = await $auth.actor.getTokens().then(x => {                       
            x = x || [];
            const first = x.find(item => item.slug == selected_slug);    
            if(first == undefined){
                console.log("No history for token slug " + selected_slug)
                alert("sorry this token does not exist");
                return false;
            }
            selected_token  = first["name"];
            selected_token_desc = first["description"];
            decimals = first["decimals"];
            contract = first["contract"] || "Native";
            icon_url = "/images/tokens/" + selected_token + ".png";
            icon_url = icon_url.toLowerCase();

            var d = first["chains"] || [];
            chains = flatten(d);

            loadTokenHistory();
        });      

    };

    async function loadTokenHistory(){
        LOADING.setLoading(true, "LOADING ....");
        await $auth.actor.getTokenQuoteHistory(selected_token, 20).then(x => {        
            var history = x[0];          
            token_history = history;            
            chart_data_final = transformTokenHistory(token_history);   
            chart.update_chart(chart_data_final);
            //since the chart transform sorted it, we pull the last to get the latest
            let recent_quote = chart_data_final[chart_data_final.length - 1];            
            most_recent_quote = recent_quote;

            chart_data_loaded = true;
            LOADING.setLoading(false, "");
        });
    };    

    async function refreshPrice(evnt){
                        
            evnt.target.setAttribute('aria-busy', 'true');      

            await $auth.actor.getTokenQuote(selected_token).then(x => {
                var json = x || []            
                var freshQuote = json[0];
                let name = freshQuote["name"];
                let symbol = freshQuote["symbol"];
                let value = freshQuote["value"];
                let value_str = freshQuote["value_str"];
                let created_at = freshQuote["created_at"];

                let n = Number(created_at);                
                freshQuote["time"] = n;
                most_recent_quote = freshQuote;
                pushNotify("success", "Price Update", value_str);

            }).then(y => {
                updateHistory();
                console.log(' refreshing ... ALL DONE');         
                evnt.target.setAttribute('aria-busy', 'false');            
            }).catch(ex => {
                console.log(ex)
                throw ex;
            });
    };

    async function updateHistory(){
        const h = await $auth.actor.getTokenQuoteHistory(selected_token, 20).then(z => {            
            var history = z[0];
            token_history = history;
        });
    };    

    function formatLocalDateTime(dt){
        var t = new Number(dt);
        return new Date(t).toString();
    };

    function formatValue(v){
        if(!v) return "loading ...";
        return "$ " + v.toFixed(2);        
    };

</script>

<section>    
    <div>
        <div style="float: right; margin-top: 50px; margin-right: 50px;">
            <!-- svelte-ignore a11y-invalid-attribute -->
            <a href="#" on:click={event => refreshPrice(event)}>Refresh</a>
        </div>
    </div>
    <h1><img src="{icon_url}" alt="icon here"  class="token-icon"/> <b>{selected_token}</b> {selected_token_desc}
    </h1>
    <p>Price: <b><code class="pico-color-green-250" >{formatValue(most_recent_quote?.value)}</code></b></p>
    <p>Updated: <b><code class="pico-color-green-500" >{timeAgoFromSecondEpoch(most_recent_quote?.time)}</code></b></p>
    <p>Decimals: <b><code class="pico-color-green-500" >{decimals}</code></b></p>
    <p>Contract: <b><code class="pico-color-green-500" >{contract}</code></b></p>
    <p>Chains: <b><code class="pico-color-green-500" >{chains}</code></b></p>    
</section>

<figure>
    <LineChart bind:this={chart} bind:data_loaded={chart_data_loaded}  />    
</figure>
<section>
    <h2>Price History</h2>
    <figure>
        <table>
          <thead>
            <tr>
              <th scope="col">Token</th>
              <th scope="col">Value</th>              
              <th scope="col">Source</th>                     
              <th scope="col">Date</th>             
            </tr>
          </thead>
          <tbody>
            {#if token_history.length > 0}
              {#each token_history as entry, i}
                  {@const created_at = entry["created_at"]}
                  {@const name = entry["name"]}
                  {@const source = entry["source"]}
                  {@const token_type = entry["token_type"]}
                  {@const value = entry["value"]}            
                  {@const value_str = entry["value_str"]}
                    <tr>
                        <td>                  
                        {name} 
                        </td>
                        <td>                  
                            {value} 
                        </td>
                        <td>                  
                            {source} 
                        </td>
                        <td title={formatLocalDateTime(created_at)}>
                            {timeAgoFromSecondEpoch(created_at)} 
                        </td>
                    </tr>                  
              {/each}
            {/if}
          </tbody>          
        </table>
      </figure>
</section>
<footer>
    <Link to="/tokens">Back</Link>
</footer>

<style>
    .token-icon{
        width: 32px;
        height: 32px;
        vertical-align:baseline;
    }
</style>