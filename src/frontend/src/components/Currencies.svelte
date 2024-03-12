<script>
  import { onMount, afterUpdate } from "svelte";
  import { auth, user, token } from "../store/auth.js";
  import { Link } from "svelte-routing";
  import { LOADING, removeBusy } from "../store/loader.js";  
  import { timeAgoFromSecondEpoch, timeAgoFromEpoch, toDateFromSeconds, timeAgo, pushNotify } from "../store/utils.js"

  $: currencies = []; 
    
  onMount(async () => {
      LOADING.setLoading(false, "LOADING ....");
      await bind_currencies();
  });
  
  async function bind_currencies(){
      console.log("im binding currencies")
      await $auth.actor.getCurrencies().then(x => {          
          currencies = x[0];
          currencies.sort(function(a, b){
            return a.name.localeCompare(b.name);
          });
      });    
  };
 

  async function refreshCurrency(event, name, name_row_id, price_row_id, source_row_id, updated_row_id){
    let price_element = document.getElementById(price_row_id);
    if(!price_element){
      console.log("Error loading price_element cell");
      return false;
    }  
    let source_element = document.getElementById(source_row_id);
    if(!source_element){
      console.log("Error loading source_element cell");
      return false;
    }
    let updated_at_element = document.getElementById(updated_row_id);
    if(!updated_at_element){
      console.log("Error loading updated_at_element cell");
      return false;
    }

    event.target.setAttribute("aria-busy", "true");

    await $auth.actor.getQuote(name).then(x => {            
      if(x.length != 1){
        console.log("problem with the price service");
        return;
      }
      var quote = x[0];
      //element.innerHTML = x;
      var ca = quote["created_at"];
      var name = quote["name"];
      var source = quote["source"];
      var symbol = quote["symbol"];
      var value = quote["value"];
      var value_str = quote["value_str"];      

      var thing = toDateFromSeconds(ca);      
      var friendlyTimeAgo = timeAgoFromSecondEpoch(thing);

      price_element.innerHTML = value_str;
      source_element.innerHTML = source;
      updated_at_element.innerHTML = friendlyTimeAgo;   

      pushNotify("success", "Update", "Latest: " + value_str);

      event.target.setAttribute("aria-busy", "false");

    }).catch(ex =>{
      pushNotify("error", "Error", "Problem updating sorry");
      throw ex;
    });

  };

</script>
    
<section>
    <h1>Currencies</h1>
</section>

<figure>
  <table>
    <thead>
      <tr>
        <th scope="col">Name</th>
        <th scope="col">Symbol</th>
        <th scope="col">Value (USD)</th>        
        <th scope="col">Source</th>        
        <th scope="col">Date</th>       
        <th scope="col"></th>
      </tr>
    </thead>

    <tbody>
      {#if currencies.length > 0}
        {#each currencies as entry, i}
            
            {@const name = entry["name"]}
            {@const symbol = entry["symbol"]}
            {@const value_str = entry["value_str"]}
            {@const source = entry["source"]}
            {@const created_at = entry["created_at"]}            
            {@const name_row_id = i + "curency_update"}
            {@const price_row_id = i + name}

            {@const source_row_id = i + "source_row_update"}
            {@const updated_row_id = i + "updated_row_update"}
            {@const image_url = "/images/fx/" + name.toLowerCase() + ".png" }            

            <tr>
              <td id={name_row_id}>
                
                <Link to="/currencies/{name}"><img src="{image_url}" alt="" class="fx-icon" /> {name} </Link>
              </td>
              <td>{symbol}</td>
              <td id={price_row_id}>{value_str}</td>
              <td id={source_row_id}>{source}</td>
              <td id={updated_row_id}>{timeAgoFromSecondEpoch(created_at)}</td>
              <td>
                {#if ($auth.loggedIn)}
                  <!-- svelte-ignore a11y-invalid-attribute -->
                  <a href="#" on:click|preventDefault={event => refreshCurrency(event, name, name_row_id, price_row_id, source_row_id, updated_row_id)}>refresh</a>
                {:else}
                  <span></span>
                {/if}
              </td>
            </tr>

        {/each}
      {/if}
    </tbody>
  
  </table>
</figure>
<section>
  <center><Link to="/tokens" >View Tokens</Link>
  </center>
</section>
<style>
  .fx-icon{
      width: 30px;
      height: 20px;
      vertical-align:auto;
  }
</style>