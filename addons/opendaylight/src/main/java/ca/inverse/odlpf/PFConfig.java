package ca.inverse.odlpf;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.Hashtable;


public class PFConfig {
    private String path;
    private Hashtable<String, String> config;
    public PFConfig(String path){
        this.path = path;
        this.config = new Hashtable<String,String>();
        this.readConfig();
    }
    
    private void readConfig(){
        File configFile = new File(this.path);
        BufferedReader configReader = null;
        
        try {
            configReader = new BufferedReader(new FileReader(configFile));
            String line = null;
            
            while ((line = configReader.readLine()) != null){
                String[] configLine = line.split("=");
                this.config.put(configLine[0], configLine[1]);
            }
        }
        catch(Exception e){
            e.printStackTrace();
            System.out.println("Configuration cannot be read.");
        }
    }
    
    public String getElement(String key){
        return this.config.get(key);
    }
    

    public static void main(String [ ] args){
        PFConfig c = new PFConfig("/etc/packetfence.conf");
        System.out.println(c.getElement("host"));
        System.out.println(c.getElement("port"));
        System.out.println(c.getElement("user"));
        System.out.println(c.getElement("pass"));
    }
}

