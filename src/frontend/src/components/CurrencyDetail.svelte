
<script>
    import { onMount } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { Link } from "svelte-routing";
    import { LOADING } from "../store/loader.js";
    import { timeAgoFromSecondEpoch, transformTokenHistory} from "../store/utils.js";
    import LineChart from './charts/LineChart.svelte';

    export let id;
    $: selected_currency = id;
    $: currency_history = [];

    let chart;
    let chart_data_loaded;
    let chart_data_final = [];

    let most_recent_quote;
    let icon_url;    

    let description = "";
    let symbol = "";

    onMount(async () => {          
        //console.log(id);
        chart_data_loaded = false;
        await loadFxHistory();
    });

    async function loadFxHistory(token){
        LOADING.setLoading(true, "LOADING ....");
        icon_url = "/images/fx/" + selected_currency.toLowerCase() + ".png";
        await $auth.actor.getQuoteHistory(selected_currency, 20).then(x => {
            var history = x[0] || [];
            if(history.length == 0){                
                LOADING.setLoading(false, "");
                return;
            };

            var history_record = history[0];
            description = history_record["description"]
            symbol = history_record["symbol"]

            currency_history = history;            
            chart_data_final = transformTokenHistory(currency_history);
            chart.update_chart(chart_data_final);

            //since the chart transform sorted it, we pull the last to get the latest
            let recent_quote = chart_data_final[chart_data_final.length - 1];
            console.log(recent_quote);
            most_recent_quote = recent_quote;

            chart_data_loaded = true;
            LOADING.setLoading(false, "");
        });
    };

    function formatLocalDateTime(dt){
        var t = new Number(dt);
        return new Date(t).toString();
    };


    function formatValue(v){
        if(!v) return "loading...";
        return symbol + "" + v.toFixed(2);
    };

</script>

<section>    
    <h1><img src="{icon_url}" alt="icon here"  class="fx-icon"/> <b>{selected_currency}</b>  {description}</h1>    
    <p>Price: <b><code class="pico-color-green-250" >{formatValue(most_recent_quote?.value)}</code></b></p>    
    <p>Symbol: <b><code class="pico-color-green-500" >{symbol}</code></b></p>
    <p>Updated: <b><code class="pico-color-green-500" >{timeAgoFromSecondEpoch(most_recent_quote?.time)}</code></b></p>     
</section>
<figure>
    <LineChart bind:this={chart} bind:data_loaded={chart_data_loaded}  />
</figure>
<section>
    <h2>History</h2>
    <figure>
        <table>
          <thead>
            <tr>
              <th scope="col">Symbol</th>
              <th scope="col">Value</th>              
              <th scope="col">Source</th>                     
              <th scope="col">Date</th>             
            </tr>
          </thead>
          <tbody>
            {#if currency_history.length > 0}
              {#each currency_history as entry, i}
      
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
    <Link to="/currencies">Back</Link>
</footer>

<style>
    .fx-icon{
        width: 30px;
        height: 20px;
        vertical-align:auto;
    }
  </style>