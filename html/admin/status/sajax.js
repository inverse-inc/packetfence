        x_get_usage(set_usage);
        setInterval("x_get_usage(set_usage)", 10000);

        function set_usage(result){
                var parts = result.split("|");

                if(parts[0] > 100){
                        parts[0] = 100;
                }

                document.getElementById('disk_usage').style.width = parts[0] + 'px';
                document.getElementById('disk_percent').innerHTML = parts[0] + '%';

                if(parts[0] <= 33){
                        document.getElementById('disk_usage').style.backgroundColor='#FFCCBF';
                }
                else if(parts[0] <= 66){
                        document.getElementById('disk_usage').style.backgroundColor='#FF9980';
                }
                else{
                        document.getElementById('disk_usage').style.backgroundColor='#FF3300';
                }

                document.getElementById('load_1').innerHTML = parts[1];
                document.getElementById('load_5').innerHTML = parts[2];
                document.getElementById('load_15').innerHTML = parts[3];

                if(parts[4] > 100){
                        parts[4] = 100;
                }

                document.getElementById('mem_usage').style.width = parts[4] + 'px';
                document.getElementById('mem_percent').innerHTML = parts[4] + '%';

                if(parts[4] <= 33){
                        document.getElementById('mem_usage').style.backgroundColor='#FFCCBF';
                }
                else if(parts[4] <= 66){
                        document.getElementById('mem_usage').style.backgroundColor='#FF9980';
                }
                else{
                        document.getElementById('mem_usage').style.backgroundColor='#FF3300';
                }

                document.getElementById('sql_queries').innerHTML = parts[5] + ' / second';
        }
