import { writable, get} from "svelte/store";


const CART_PRODUCTS = [
    // { name: "TEST", sku: "10", price: 1.11 }    
];

const backingStore = writable(CART_PRODUCTS)
const { subscribe, set, update } = backingStore;

const addProduct = (product) =>
  update((products) => {
    console.log("ADDING PRODUCT")
    return [...products, product];
});

// const removeProduct = (product) =>
//     update((products) => {
//     console.log("REMOVING PRODUCT")
// });

const reset = () => {    
    set([]);
    console.log("cart was reset")
};

const total = () =>{  
  var thing = details();
  return thing["total"] || 0.00;
}

const details = () => { 

  var items = get(backingStore);
  var total = 0.00;
  var sub_total = 0.00;
  var tax_total = 0.00;
  
  items.forEach(x => {
    var this_price = x.price;    
    var this_tax1 = x.tax1rate;
    var this_tax2 = x.tax2rate;
    if(this_price <= 0){
      throw new Error("invalid item");
    }
    if (this_tax1 > 0) {
      var line_total_tax = this_price * (this_tax1 + this_tax2);
      tax_total += line_total_tax;
      this_price = this_price * (1 + this_tax1);
    }
    sub_total += x.price;
  })

  //console.log("TOTAL TAX: " + tax_total);
  total = sub_total + tax_total;
  //console.log("CART TOTAL: " + total);

  return {    
    "sub_total": sub_total.toFixed(2),
    "tax_total": tax_total.toFixed(2),
    "total": total.toFixed(2),
    "discount": 0
  }

};


export default {
  subscribe,
  addProduct,
  total,  
  reset,
  details,
};
