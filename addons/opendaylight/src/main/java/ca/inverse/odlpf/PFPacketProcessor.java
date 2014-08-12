package ca.inverse.odlpf;

import java.net.InetAddress;
import java.net.URL;
import java.net.UnknownHostException;
import java.net.HttpURLConnection;
import java.io.DataOutputStream;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import javax.xml.bind.DatatypeConverter;
import org.opendaylight.controller.sal.core.Node;
import org.opendaylight.controller.sal.core.NodeConnector;
import org.opendaylight.controller.sal.packet.Ethernet;
import org.opendaylight.controller.sal.packet.IDataPacketService;
import org.opendaylight.controller.sal.packet.IListenDataPacket;
import org.opendaylight.controller.sal.packet.IPv4;
import org.opendaylight.controller.sal.packet.Packet;
import org.opendaylight.controller.sal.packet.PacketResult;
import org.opendaylight.controller.sal.packet.RawPacket;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.DataOutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import javax.net.ssl.*;
import javax.xml.bind.DatatypeConverter;
import org.opendaylight.controller.sal.utils.HexEncode;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import org.json.*;
import java.util.Hashtable;
import java.util.ArrayList;
 

public class PFPacketProcessor {

    private static final PFConfig pfConfig = new PFConfig("/etc/packetfence.conf");
    private static Hashtable<String, String> transactionCache = new Hashtable<String, String>();
    private static ArrayList<String> ignoredCache = new ArrayList<String>();

    private String sourceMac;
    private String switchId;
    private String port;
    private Packet packet;

    PFPacketProcessor(String sourceMac, String switchId, String port, Packet packet){
        this.sourceMac = sourceMac;
        this.switchId = switchId;
        this.port = port;
        this.packet = packet; 
    }

    public PacketResult processPacket(){
        String portUniqueId = switchId + "-" + port;
        if(!transactionCache.containsKey(sourceMac) && !PFPacketProcessor.ignoredCache.contains(portUniqueId)){
            PFPacketProcessor.transactionCache.put(sourceMac, sourceMac);
            JSONObject response = this.getPacketFenceActions();
            try{
                JSONArray result = response.getJSONArray("result");
                JSONObject data = result.getJSONObject(0); 
                String action = data.getString("action");
                if (action.equals("ignored")){
                    PFPacketProcessor.ignoredCache.add(portUniqueId);
                }
                System.out.println(data.toString());
            }
            catch(Exception e){
                e.printStackTrace();
            }
            PFPacketProcessor.transactionCache.remove(sourceMac);
            return PacketResult.KEEP_PROCESSING;
        }
        else if(PFPacketProcessor.transactionCache.containsKey(sourceMac)){
            System.out.println("Ignoring packet because a current transaction is already started");
            return PacketResult.IGNORED;
        }
        else if(PFPacketProcessor.ignoredCache.contains(portUniqueId)){
            System.out.println("Ignoring packet because it was previously discovered as an uplink");
            return PacketResult.IGNORED;
        }
        return PacketResult.IGNORED;

    }

    /*
     * Sends an HTTP request to the PacketFence API
     * Will trigger the DNS poisoning depending on the node's state
     */
    private JSONObject getPacketFenceActions() {
        this.setupHttpsConnection();	
    	try{
            JSONObject jsonBody = this.getPacketFenceJSONPayload();

	    	String request = "https://"+pfConfig.getElement("host")+":"+pfConfig.getElement("port")+"/";
	    	
	    	String authentication = DatatypeConverter.printBase64Binary(new String(pfConfig.getElement("user")+":"+pfConfig.getElement("pass")).getBytes());
	    	URL url = new URL(request); 
	    	HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();           
	    	connection.setDoOutput(true);
	    	connection.setDoInput(true);
	    	connection.setInstanceFollowRedirects(false); 
	    	connection.setRequestMethod("POST"); 
	    	connection.setRequestProperty("Content-Type", "application/json-rpc");
	    	connection.setRequestProperty("charset", "utf-8");
	    	connection.setRequestProperty("Content-Length", "" + Integer.toString(jsonBody.toString().getBytes().length));
	    	connection.setRequestProperty("Authorization", "Basic "+authentication);
	    	connection.setUseCaches (false);
	
	    	DataOutputStream wr = new DataOutputStream(connection.getOutputStream ());
	    	wr.writeBytes(jsonBody.toString());
	    	wr.flush();
	    	wr.close();
	    	connection.disconnect();	
	    	System.out.println(jsonBody.toString());

            BufferedReader response = null;  
            response = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            String line = null;
            while ((line = response.readLine()) != null) {
                System.out.println(line);
	    	    return new JSONObject(line);
            }

    	}
    	catch(Exception e){
    		e.printStackTrace();
    		return new JSONObject();
    	}
    	return new JSONObject();
    }
    
    private void setupHttpsConnection(){
    	TrustManager[] trustAllCerts = new TrustManager[]{
		    new X509TrustManager() {
		        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
		            return null;
		        }
		        public void checkClientTrusted(
		            java.security.cert.X509Certificate[] certs, String authType) {
		        }
		        public void checkServerTrusted(
		            java.security.cert.X509Certificate[] certs, String authType) {
		        }
		    }
		};
    	try {
    	    SSLContext sc = SSLContext.getInstance("SSL");
    	    sc.init(null, trustAllCerts, new java.security.SecureRandom());
    	    HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
    	} catch (Exception e) {
            e.printStackTrace();
    	}
    	
    	HttpsURLConnection.setDefaultHostnameVerifier(new HostnameVerifier()
        {
            public boolean verify(String hostname, SSLSession session)
            {
                if (hostname.equals(pfConfig.getElement("host")))
                    return true;
                return false;
            }
        });

    }
    
    private JSONObject getPacketFenceJSONPayload(){
        try{
            JSONObject jsonBody = new JSONObject();
            jsonBody.put("jsonrpc", "2.0");
            jsonBody.put("id", "1");
            jsonBody.put("method", "openflow_authorize");
            JSONObject params = new JSONObject();
            params.put("mac", sourceMac);
            params.put("switch_id", switchId);
            params.put("port", port);
            jsonBody.put("params", params);
            return jsonBody;
        }
        catch (Exception e){
            e.printStackTrace();
            return new JSONObject();
        }
    }
 
}
