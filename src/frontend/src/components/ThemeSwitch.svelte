<script>   
    import { onMount } from 'svelte';
    import { createEventDispatcher } from 'svelte';    

    const dispatch = createEventDispatcher();

    const removeTooltip = (timeInt = 1750) => {
        setTimeout(()=>{
            document.getElementById('theme_switcher')?.blur();
    }, timeInt)};
    
    const themer = {
        _scheme: "auto",
        html: document.querySelector("html"),        
        os_default: '<svg viewBox="0 0 16 16"><path fill="currentColor" d="M8 15A7 7 0 1 0 8 1v14zm0 1A8 8 0 1 1 8 0a8 8 0 0 1 0 16z"/></svg>',
        sun: '<svg viewBox="0 0 16 16"><path fill="currentColor" d="M8 11a3 3 0 1 1 0-6a3 3 0 0 1 0 6zm0 1a4 4 0 1 0 0-8a4 4 0 0 0 0 8zM8 0a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 0zm0 13a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 13zm8-5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2a.5.5 0 0 1 .5.5zM3 8a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2A.5.5 0 0 1 3 8zm10.657-5.657a.5.5 0 0 1 0 .707l-1.414 1.415a.5.5 0 1 1-.707-.708l1.414-1.414a.5.5 0 0 1 .707 0zm-9.193 9.193a.5.5 0 0 1 0 .707L3.05 13.657a.5.5 0 0 1-.707-.707l1.414-1.414a.5.5 0 0 1 .707 0zm9.193 2.121a.5.5 0 0 1-.707 0l-1.414-1.414a.5.5 0 0 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .707zM4.464 4.465a.5.5 0 0 1-.707 0L2.343 3.05a.5.5 0 1 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .708z"/></svg>',
        moon: '<svg viewBox="0 0 16 16"><g fill="currentColor"><path d="M6 .278a.768.768 0 0 1 .08.858a7.208 7.208 0 0 0-.878 3.46c0 4.021 3.278 7.277 7.318 7.277c.527 0 1.04-.055 1.533-.16a.787.787 0 0 1 .81.316a.733.733 0 0 1-.031.893A8.349 8.349 0 0 1 8.344 16C3.734 16 0 12.286 0 7.71C0 4.266 2.114 1.312 5.124.06A.752.752 0 0 1 6 .278zM4.858 1.311A7.269 7.269 0 0 0 1.025 7.71c0 4.02 3.279 7.276 7.319 7.276a7.316 7.316 0 0 0 5.205-2.162c-.337.042-.68.063-1.029.063c-4.61 0-8.343-3.714-8.343-8.29c0-1.167.242-2.278.681-3.286z"/><path d="M10.794 3.148a.217.217 0 0 1 .412 0l.387 1.162c.173.518.579.924 1.097 1.097l1.162.387a.217.217 0 0 1 0 .412l-1.162.387a1.734 1.734 0 0 0-1.097 1.097l-.387 1.162a.217.217 0 0 1-.412 0l-.387-1.162A1.734 1.734 0 0 0 9.31 6.593l-1.162-.387a.217.217 0 0 1 0-.412l1.162-.387a1.734 1.734 0 0 0 1.097-1.097l.387-1.162zM13.863.099a.145.145 0 0 1 .274 0l.258.774c.115.346.386.617.732.732l.774.258a.145.145 0 0 1 0 .274l-.774.258a1.156 1.156 0 0 0-.732.732l-.258.774a.145.145 0 0 1-.274 0l-.258-.774a1.156 1.156 0 0 0-.732-.732l-.774-.258a.145.145 0 0 1 0-.274l.774-.258c.346-.115.617-.386.732-.732L13.863.1z"/></g></svg>',
   
        rootAttribute: "data-theme",
        localStorageKey: "picoPreferredColorScheme",       

        // Init
        init() {
            this.scheme = this.schemeFromLocalStorage;   //refresh the theme
            this.isLight = this.scheme == "light" ? true : false;
            this.html.setAttribute('data-theme', this.isLight? 'light':'dark')
            var switchTheme = document.getElementById('theme_switcher')            
            switchTheme.innerHTML = this.isLight? this.sun : this.moon
            this.html.setAttribute('data-theme', this.isLight? 'light':'dark')
            this.initSwitchers();            
        },

        // Get color scheme from local storage
        get schemeFromLocalStorage() {
            return window.localStorage?.getItem(this.localStorageKey) ?? this._scheme;
        },

        // Preferred color scheme
        get preferredColorScheme() {
            return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
        },

        // Init switchers
        initSwitchers() {
            var switcher = document.getElementById('theme_switcher')
            switcher.addEventListener('click', (e)=> {
                
                e.preventDefault()                
                this.isLight = !this.isLight                
                this.html.setAttribute('data-theme', this.isLight? 'light':'dark')
                switcher.innerHTML = this.isLight? this.sun : this.moon
                //switcher.setAttribute('data-tooltip', `theme ${this.isLight?'light':'dark'}`)
                var result = this.isLight ? 'light':'dark';                
                console.log("setting theme to " + result);
                this.scheme = result;

                var dresult = dispatch('updatedTheme',  this.isLight);
                //console.log("dispatched event " + dresult)
                removeTooltip()
                
            });
        
        },

        // Set scheme
        set scheme(scheme) {
            if (scheme == "auto") {
                this._scheme = this.preferredColorScheme;
            } else if (scheme == "dark" || scheme == "light") {
                this._scheme = scheme;
            }
            this.applyScheme();
            this.schemeToLocalStorage();            
        },

        // Get scheme
        get scheme() {
            return this._scheme;
        },

        // Apply scheme
        applyScheme() {
            document.querySelector("html")?.setAttribute(this.rootAttribute, this.scheme);
        },

        // Store scheme to local storage
        schemeToLocalStorage() {
            window.localStorage?.setItem(this.localStorageKey, this.scheme);
        },

    };

    onMount(() => {
        
        themer.init();        
        var dresult = dispatch('updatedTheme', themer.isLight);
        //console.log("dispatched event " + dresult)
    });

    //onMount(() => themer.init());
    
  </script>

<div style="width: 28px; height: 28px;">
    <a href={'#'} id="theme_switcher" class="theme_switcher">&nbsp;</a>
</div>


<style>

.theme_switcher {
    width: var(--font-size);
    height: var(--font-size);
    color: var(--contrast);
}
</style>