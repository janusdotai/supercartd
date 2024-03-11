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

/* 
 #cover-spin {
    position:fixed;
    width:100%;
    left:0;right:0;top:0;bottom:0;
    background-color: rgba(255,255,255,0.7);
    z-index:9999;
    display:none;
}

@-webkit-keyframes spin {
	from {-webkit-transform:rotate(0deg);}
	to {-webkit-transform:rotate(360deg);}
}

@keyframes spin {
	from {transform:rotate(0deg);}
	to {transform:rotate(360deg);}
}

#cover-spin::after {
    content:'';
    display:block;
    position:absolute;
    left:48%;top:40%;
    width:40px;height:40px;
    border-style:solid;
    border-color:black;
    border-top-color:transparent;
    border-width: 4px;
    border-radius:50%;
    -webkit-animation: spin .8s linear infinite;
    animation: spin .8s linear infinite;
} */

</style>