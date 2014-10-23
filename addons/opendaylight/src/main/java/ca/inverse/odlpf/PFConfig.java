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
    
    /*
     * Method that reads the configuration file and creates the key/value hash
     */
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
    
    /*
     * Get an element in the configuration hash
     */
    public String getElement(String key){
        return this.config.get(key);
    }
    
    /*
     * Transform a MAC of format 001122334455 to a bytes array
     */
    public byte[] getMacBytes(String mac){
        int position = 0;
        int i=0;
        byte[] bytes = new byte[6];
        while (position < mac.length()){
            String substring = mac.substring(i, Math.min(position + 2,mac.length()));
            int substringIntValue = Integer.parseInt(substring, 16);
            bytes[i] = (byte)substringIntValue;
            i++;
            position += 2;
        }
        return bytes;
    }

    public static void main(String [ ] args){
        PFConfig c = new PFConfig("/etc/packetfence.conf");
        System.out.println(c.getElement("host"));
        System.out.println(c.getElement("port"));
        System.out.println(c.getElement("user"));
        System.out.println(c.getElement("pass"));
    }
}

