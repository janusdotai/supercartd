<script>
    import { onMount } from 'svelte';
    import { createChart } from 'lightweight-charts';    
    
    export let data_loaded = false;

    export function update_chart(latest_data){

        if(latest_data.length == 0){
            console.log("empty chart data ")
            return;
        }
        
        const chartOptions = 
        {
            layout: {
                background: { color: '#222', type: 'solid' },
                textColor: '#DDD',
            },
            grid: {
                vertLines: { color: '#444' },
                horzLines: { color: '#444' },
            }
        };

        //console.log(latest_data)

        let avg = 0;
        let total = 0;
        latest_data.forEach(x => {
            //console.log(x)
            total += x["value"]
        })
        //console.log(total)
        avg = Math.round(total / latest_data.length, 2);
        //console.log(avg)

        //const chartOptions = { layout: { textColor: 'white', background: { type: 'solid', color: 'black' } } };

        //chart = createChart(document.getElementById('line_chart'), chartOptions);      
        //const candleStickData = generateCandlestickData();      
        //const candleStickData = chart_data;
        //const mainSeries = chart.addCandlestickSeries();                
        //mainSeries.setData(candleStickData);
        // chart.timeScale().applyOptions({
        //     borderColor: '#71649C',
        //});

        // console.log("IM UPDATING MY DATA chart_load");
        // console.log(latest_data);

        
        const chart = createChart(document.getElementById('line_chart'), chartOptions);
        const baselineSeries = chart.addBaselineSeries({ baseValue: { type: 'price', price: avg }, topLineColor: 'rgba( 38, 166, 154, 1)', topFillColor1: 'rgba( 38, 166, 154, 0.28)', topFillColor2: 'rgba( 38, 166, 154, 0.05)', bottomLineColor: 'rgba( 239, 83, 80, 1)', bottomFillColor1: 'rgba( 239, 83, 80, 0.05)', bottomFillColor2: 'rgba( 239, 83, 80, 0.28)' });

        //const data = [{ value: 1, time: 1642425322 }, { value: 8, time: 1642511722 }, { value: 10, time: 1642598122 }, { value: 20, time: 1642684522 }, { value: 3, time: 1642770922 }, { value: 43, time: 1642857322 }, { value: 41, time: 1642943722 }, { value: 43, time: 1643030122 }, { value: 56, time: 1643116522 }, { value: 46, time: 1643202922 }];

        baselineSeries.setData(latest_data);
        chart.timeScale().fitContent();

       
        chart.resize(window.innerWidth - 90, window.innerHeight - 90);

        return "done";       

    };
  
    onMount(() => {      
        
    });

    function setDisplay(loaded){
        if(loaded){
            return "display: block;";
        }else{
            return "display: none;"
        }
    }

    // window.addEventListener('resize', () => {
    //     chart.resize(window.innerWidth - 90, window.innerHeight - 90);
    //     console.log("im resizing...")
    // });

  </script>
  
  <div id="line_chart" style="{setDisplay(data_loaded)}"></div>
  
  <style>
    
  </style>
  