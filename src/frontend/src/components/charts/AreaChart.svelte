<script>
    import { onMount } from 'svelte';
    import { createChart, LineStyle, CrosshairMode } from 'lightweight-charts';    
    import { debounce, timeAgoFromEpoch } from "../../store/utils.js"   
    
    export let data_loaded = false;
    let chart;

    export function update_chart(latest_data){
        
        console.log("Updating AREA CHART")

        if(latest_data.length == 0){
            console.log("empty chart data ")
            return;
        }        
       
        const chartOptions = { 
            layout: { 
                textColor: 'black', 
                background: { type: 'solid', color: '##010127' } 
            },
            crosshair: {
                // Change mode from default 'magnet' to 'normal'.
                // Allows the crosshair to move freely without snapping to datapoints
                mode: CrosshairMode.Normal,

                // Vertical crosshair line (showing Date in Label)
                vertLine: {
                    width: 8,
                    color: '#C3BCDB44',
                    style: LineStyle.Solid,
                    labelBackgroundColor: '#9B7DFF',
                },

                // Horizontal crosshair line (showing Price in Label)
                horzLine: {
                    color: '#9B7DFF',
                    labelBackgroundColor: '#9B7DFF',
                },
            },
        };

        chart = createChart(document.getElementById('area_chart'), chartOptions);
        const areaSeries = chart.addAreaSeries({ lineColor: '#2962FF', topColor: '#2962FF', bottomColor: 'rgba(41, 98, 255, 0.28)' });

        //const data = [{ value: 0, time: 1642425322 }, { value: 8, time: 1642511722 }, { value: 10, time: 1642598122 }, { value: 20, time: 1642684522 }, { value: 3, time: 1642770922 }, { value: 43, time: 1642857322 }, { value: 41, time: 1642943722 }, { value: 43, time: 1643030122 }, { value: 56, time: 1643116522 }, { value: 46, time: 1643202922 }];
        const data = latest_data;

        areaSeries.setData(data);

        chart.timeScale().applyOptions({
            barSpacing: 10,
        });

        chart.timeScale().fitContent();
       
       
        //chart.resize(window.innerWidth / 2, window.innerHeight / 2);
        chart.resize(window.innerWidth - 150, window.innerHeight - 150);

        data_loaded = true;

        return "done";       

    };
  
    onMount(() => {      

        const resizer_func = (event) => {
            //chart.resize(window.innerWidth / 2, window.innerHeight / 2);            
            chart.resize(window.innerWidth - 90, window.innerHeight - 90);
            console.log("im resizing...")
        }

        window.addEventListener('resize',  debounce(resizer_func, 250));
        
        return ()=>{
            // this function is called when the component is destroyed
            window.removeEventListener("resize", resizer_func);
        }
        
    });

    function setDisplay(loaded){
        if(loaded){
            return "display: block;";
        }else{
            return "display: none;"
        }
    }  

  </script>
  
  <div id="area_chart" style="{setDisplay(data_loaded)}" ></div>
  
 