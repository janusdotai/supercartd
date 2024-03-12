import App from "./App.svelte";
import AppCheckout from "./AppCheckout.svelte";

let IS_CHECKOUT = window.location.pathname.startsWith("/checkout/");
let IS_RECEIPT = window.location.pathname.startsWith("/receipt/");

let app;
if(IS_CHECKOUT){    
  app = new AppCheckout({
    target: document.body,    
  });

}else if(IS_RECEIPT){
  app = new AppCheckout({
    target: document.body,    
  });
}else{
  app = new App({
    target: document.body,  
  });
}

export default app;