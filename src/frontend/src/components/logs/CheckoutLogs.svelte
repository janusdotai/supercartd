<script>
import { Link, navigate } from "svelte-routing";
import { onMount, afterUpdate } from "svelte";
import { auth, user, token } from "../../store/auth.js";
import { toDateFromSeconds, ellipsis, timeAgoFromSecondEpoch } from "../../store/utils.js";

$: logs = [];

onMount(async () => {  
  const fetch_logs = await $auth.actor.getMerchantId().then(x => {
    //console.log("i found the checkout")
    //console.log(x);    
    return x;
  }).then(y => {
    //console.log("cid " + y);
    bindLogs(y);
  });

});

async function bindLogs(cid){
  console.log("fetching logs for " + cid);  
  const yo  = await $auth.actor.getMerchantLogs(cid).then(y => {
    //console.log(y);
    logs = y;
  });
}

function goBack(){
  navigate("/admin");
}

</script>

<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>View Logs</li>
    </ul>
</nav>


<h1>Checkout logs</h1>
<figure>
  <table>
    <thead>
      <tr>
        <!-- <th scope="col">ID</th> -->
        <th scope="col">Date</th>
        <th scope="col">Owner</th>      
        <th scope="col">Status</th>        
        <th scope="col">Message</th>        
      </tr>
    </thead>
    <tbody>
      {#if logs.length > 0}
        {#each logs as entry}
        {@const created_at = entry["created_at"]}
        {@const owner = entry["owner"]}
        {@const status = entry["status"]}
        {@const status_text = entry["status_text"]}
        <tr>
          <!-- <td>{entry[0]}</td> -->
          <td title={timeAgoFromSecondEpoch(created_at)}>{toDateFromSeconds(created_at)}</td>
          <td>{ellipsis(owner, 20)}</td>
          <td>{status}</td>
          <td>{status_text}</td>        
        </tr>        
        {/each}
      {/if}
    </tbody>
    <tfoot>
      <tr>
        <th ></th>
        <td ></td>
        <td ></td>        
      </tr>
    </tfoot>
  </table>
</figure>
  <br>
  <!-- <a href="/admin" role="button" class="secondary" id="cancel_edit" style="display: block;">Back</a> -->  
  <!-- <div role="button" tabindex="0" on:click={goBack}>Back</div> -->
  <button class="secondary" on:click={goBack}>Back</button>
  <!-- <Link to="/admin">Back</Link> -->
