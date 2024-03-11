<script>
  import { Router, Link, Route } from "svelte-routing";
  import { auth, user, IS_PRODUCTION } from "./store/auth.js";

  import Home from "./routes/Home.svelte";
  import About from "./routes/About.svelte";
  import Admin from "./routes/Admin.svelte";  
  import Api from "./components/Api.svelte";

  import Auth from "./components/Auth.svelte";
  import EditStore from "./components/EditStore.svelte";
  import LoadingModal from "./components/LoadingModal.svelte";
  import ProtectedRoute from "./components/ProtectedRoute.svelte";  
  import CanisterIds from "./components/CanisterIds.svelte";
  import ThemeSwitch from "./components/ThemeSwitch.svelte";  
  import CheckoutLogs from "./components/logs/CheckoutLogs.svelte";  
  import Tokens from "./components/Tokens.svelte";  
  import Currencies from "./components/Currencies.svelte";
  import TokenDetail from "./components/TokenDetail.svelte";
  import CurrencyDetail from "./components/CurrencyDetail.svelte";
  import Products from "./components/Products.svelte";
  import ProductEdit from "./components/ProductEdit.svelte";
  import Payments from "./components/Payments.svelte";
  import PaymentsEdit from "./components/PaymentsEdit.svelte";  
  import Orders from "./components/Orders.svelte";
  import ReceiptDetail from "./components/ReceiptDetail.svelte";  
  
  export let url = "";
  
  let prod = IS_PRODUCTION;
  if(IS_PRODUCTION){
    console.log("IS_PRODUCTION is: %c" + prod + "", "color:green");
  }else{
    console.log("IS_PRODUCTION is: %c" + prod + "", "color:yellow");
  }

  //var user_theme = localStorage.getItem("picoPreferredColorScheme");
  //console.log("user has theme " + user_theme);
  function navHandler(){
    let q = document.querySelector(".nav-dropdown");
    q.removeAttribute("open");
    return false;
  }

  function updateThemeUI(event){            
    if(event.detail === true){ //light    
      var element = document.querySelector("#nav_header");      
      element.style.borderBottom = "3px solid #e2e8ec";
    }else{
      var element = document.querySelector("#nav_header");      
      element.style.borderBottom = "3px solid orange";     
    }
  }

</script>

<Router {url}>  
  
  <header class="container-fluid header-main" id="nav_header">  
      <div class="grid" >
        <div class="header-left">
          <nav>           
            <ul>       
              <li>
                <details role="list" dir="rtl" class="dropdown nav-dropdown" data-theme="dark">
                  <summary aria-haspopup="listbox" role="link" class="dark-bg" >
                    <span>Supercartd</span>
                  </summary>

                  <ul dir="rtl">
                    <li><Link to="/"  on:click={navHandler}>Home</Link></li>
                    <li><Link to="/about"  on:click={navHandler} >About</Link></li>                   
                    <li><Link to="/tokens"  on:click={navHandler}>Tokens</Link></li>
                    <li><Link to="/admin"  on:click={navHandler}>Admin</Link></li>
                  </ul>

                </details>
              </li>
            </ul>        
          </nav>     
        </div>        
        <div>         
          <div class="box">           
            <div class="login">
              <Auth />
            </div>          
            <div class="theme-switcher-container">
              <ThemeSwitch on:updatedTheme={updateThemeUI}/>
            <div>              
          </div>
        </div>        
      </div>
  </header>
  
  <main class="container-fluid" style="padding-top: 5px; margin-bottom: 0px;">
    <div>          
      <Route path="/tokens" component={Tokens} />
      <Route path="/tokens/:id" let:params >
        <TokenDetail id="{params.id}" />
      </Route>
      <Route path="/currencies" component={Currencies} />
      <Route path="/currencies/:id" let:params >
        <CurrencyDetail id="{params.id}" />
      </Route>
      
      <ProtectedRoute path="/admin" component={Admin} />            
      <ProtectedRoute path="/store/edit" component={EditStore} />
      <ProtectedRoute path="/store/logs" component={CheckoutLogs} />
      
      <ProtectedRoute path="/store/products" component={Products} />
      <ProtectedRoute path="/store/products/add" component={ProductEdit} />
      <Route path="/store/products/edit/:pid" let:params > <!-- todo -->
        <ProductEdit id="{params.pid}" />
      </Route>

      <ProtectedRoute path="/store/payments" component={Payments} />      
      <Route path="/store/payments/edit/:slug" let:params > <!-- todo -->
        <PaymentsEdit slug="{params.slug}" />
      </Route>

      <ProtectedRoute path="/store/orders" component={Orders} />

      <Route path="/store/receipts/:rid" let:params > <!-- todo -->
        <ReceiptDetail rid="{params.rid}" />
      </Route>


      <Route path="/about" component={About} />
      <Route path="/connect" component={Api} />
      <Route path="/"><Home /></Route>
      <Route>
        <h1>404 - Not Found</h1>
        <p>Sorry, the page you are looking for does not exist!</p>
        <p>Go back to <a href="/">home</a></p>
      </Route>
    </div> 
  </main>
<hr>
  <footer class="container-fluid">    
    <div class="grid">
      <div>
        <CanisterIds />   
      </div>     
    </div> 
    <div style="text-align: center;">      
      Technical Demo 2024<br>
      Running on the Internet Computer
    </div>
  </footer>

  <LoadingModal />

</Router>


<style>

  .header-main{
    /* border: solid 2px orange; */
    padding-top: 5px;
    padding-bottom: 10px;
    margin-bottom: 0px; 
  }
  .header-left{
    border: none 1px red;    
  }
  .box{
    display: flex;  
    border: none 1px blue;    
    margin-left: auto;
  }  
  .login{   
    margin-left: auto;
    border: none 1px green;        
  }  
  .theme-switcher-container{    
    margin-left: 10px;
    width: 40px;   
    border: none 1px red;
  }
  .dark-bg{
    background-color: #11191f;
    padding: 10px;
  }

</style>
