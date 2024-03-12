import { writable } from 'svelte/store';

export function removeBusy(){
  // Select all elements with the aria-busy attribute
  const elementsWithAriaBusy = document.querySelectorAll('[aria-busy]') || [];
  // Loop through the selected elements and remove the aria-busy attribute    
  elementsWithAriaBusy.forEach(element => {
    element.removeAttribute('aria-busy');
  });  
}

const newLoading = () => {
  const { subscribe, update, set } = writable({
    status: 'IDLE', // IDLE, LOADING, NAVIGATING
    message: '',
  });

  function setNavigate(isNavigating) {
    update(() => {
      return {
        status: isNavigating ? 'NAVIGATING' : 'IDLE',
        message: '',
      };
    });
  }

  function setLoading(isLoading, message) {
    update(() => {
      return {
        status: isLoading ? 'LOADING' : 'IDLE',
        message: isLoading ? message : '',
      };
    });
  }

  return { subscribe, update, set, setNavigate, setLoading };
};

export const LOADING = newLoading();



