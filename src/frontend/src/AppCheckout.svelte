<script>
    import { Router, Link, Route } from "svelte-routing";
    import { auth, user, IS_PRODUCTION } from "./store/auth.js";
    import NotFound from "./routes/NotFound.svelte";
    import CheckoutRoute from "./routes/CheckoutRoute.svelte";
    import LoadingModal from "./components/LoadingModal.svelte";
    import ReceiptRoute from "./routes/ReceiptRoute.svelte";
    
    export let url = "";
    let prod = IS_PRODUCTION;
    if(IS_PRODUCTION){
        console.log("IS_PRODUCTION is: %c" + prod + "", "color:green");
    }else{
        console.log("IS_PRODUCTION is: %c" + prod + "", "color:yellow");
    } 
    
</script>

<Router {url}> 
    <main class="container-fluid" style="padding-top: 2px; margin-bottom: 2px;">                   
        <div style="border: none 1px lime;">
          <Route path="/checkout" component={NotFound} />
          <Route path="/checkout/:cid" let:params>                    
            <CheckoutRoute cid="{params.cid}" />
          </Route>

          <Route path="/receipt" component={NotFound} />
          <Route path="/receipt/:rid" let:params>                    
            <ReceiptRoute rid="{params.rid}" />
          </Route>
          
          <Route>
            <h1>404 - Not Found</h1>
            <p>Sorry, the page you are looking for does not exist!</p>
            <p>Go back to <a href="/">home</a></p>
          </Route>

        </div>
        <LoadingModal />
    </main>
    
</Router>

    
