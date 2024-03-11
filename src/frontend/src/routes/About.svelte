<script>    

function loadIcpLogo(){
  var x = window.localStorage?.getItem("picoPreferredColorScheme") ?? "dark";
  if(x === "dark"){
    return "/images/icp_logo_dark2.png";
  }else{
    return "/images/icp_logo_light2.png";
  }
}

</script>
<nav aria-label="breadcrumb">
  <ul>
    <li><a href="/">Home</a></li>    
    <li>About</li>
  </ul>
</nav>

<section>
    <hgroup>
        <h2>About</h2>      
      </hgroup>
</section>
<article>
  <p>Supercartd is an MVP of a multichain ecommerce store. You can login using an <a href="https://internetcomputer.org/internet-identity">Internet Identity</a> and create your own basic ecommerce storefront and accept payments in tokens across various chains.
  </p>
  <p>
    This tech demo was created to see what was possible with the Internet computer using stable storage and https outcalls.
    The overall goal is to explore decentralized ecommerce using general purpose public blockchains.
    The platform uses open RPC nodes and free oracle services to confirm transactions and has no other dependencies other than <a href="https://internetcomputer.org/icp-tokens/">cycles</a>. 
  </p>
  <p><b>THIS IS BETA SOFTWARE - THE CODE HAS NOT BEEN AUDITED USE AT YOUR OWN RISK</b></p>
  <p>Supercart offers:</p>
  <ul>    
    <li>Simple onboarding (just click 'Login' at the top of the page)</li>
    <li>Free storefront (create your own ecommerce shop)</li>
    <li>Multichain token pricing engine (transparent price feeds and sources)</li>
    <li>Free simple checkout (to send your customers to)</li>  
  </ul> 

  <p>This platfrom was built with <a href="https://svelte.dev/">Svelte</a> and <a href="https://internetcomputer.org/docs/current/motoko/main/motoko">Motoko</a>.
  </p>  
  <section>
    <p>Github Links: <code>coming soon - pending audit</code>
    </p>
    <p>Social Links: <code>coming soon</code></p>
  </section>
  <article class="detail-center" >
    <img src={loadIcpLogo()} alt="icp logo" class="icp-logo"/>
  </article>

</article>
<style>
  .detail-center{
    text-align: center;
  }
  .icp-logo{
    width: 15%;
    height: 15%;
  }
</style>