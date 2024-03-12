<script >
  import { LOADING } from "../store/loader.js";

  $: if ($LOADING.status === 'NAVIGATING') {
    setTimeout(() => {
      if ($LOADING.status === 'NAVIGATING') {
        $LOADING.status = 'LOADING'
      }
    }, 400)
  }
  
</script>

{#if $LOADING.status === 'LOADING'}
  <div class="container-fluid loading" >
    {#if $LOADING.message}
      <div >
        <h1>
          <p>{$LOADING.message}</p>
        </h1>
      </div>
    {:else}
    <div >      
    </div>
    {/if}
</div>
{/if}

<style>
  .loading {
    
    background-color: black;
    
    color: white;
    opacity: 0.6;
    
    font-family: PT Sans Narrow;
    font-size: x-large;
    font-weight: bold;

    display: flex;
    align-items: center;
    justify-content: center;
    
    /* min-width: 500px;
    min-height: 500px; */
    
    position: fixed;
    top: 0;
    left: 0;
    height: 100%;
    width: 100%;

    /* position: fixed;
    top: 20%;
    left: 20%;
    transform: translate(-20%, -20%); */       
}

</style>