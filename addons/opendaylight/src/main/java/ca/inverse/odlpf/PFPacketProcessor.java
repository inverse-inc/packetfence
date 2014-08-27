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

    private static final Logger log = LoggerFactory.getLogger(PacketHandler.class);

    private static final PFConfig pfConfig = new PFConfig("/etc/packetfence.conf");
    private static ArrayList<String> transactionCache = new ArrayList<String>();
    private static ArrayList<String> ignoredCache = new ArrayList<String>();
    private static final byte[] PF_MAC = {(byte)0, (byte)80, (byte)86, (byte)157, (byte)0, (byte)11};

    private String sourceMac;
    private String switchId;
    private String port;
    private PFPacket packet;
    private PacketHandler packetHandler;

    PFPacketProcessor(String switchId, String port, RawPacket packet, PacketHandler packetHandler){
        this.packetHandler = packetHandler;
        this.packet = new PFPacket(packet, packetHandler); 
        this.sourceMac = this.packet.getSourceMac();
        this.switchId = switchId;
        this.port = port;
    }

    public PacketResult processPacket(){
        if( !this.alreadyInTransaction()  && !this.shouldIgnorePacket() ){
            this.startTransaction();
            JSONObject response = this.getPacketFenceActions();
            PacketResult result = this.handlePacketFenceResponse(response);
            this.finishTransaction();
            return result;
        }
        else if(this.alreadyInTransaction()){
            log.info("Ignoring packet because a current transaction is already started");
            System.out.println("Ignoring packet because a current transaction is already started");
            return PacketResult.IGNORED;
        }
        else if( this.shouldIgnorePacket() ){
            System.out.println("Ignoring packet because it was previously declared as to be ignored");
            return PacketResult.IGNORED;
        }
        return PacketResult.IGNORED;

    }
    
    private void addToIgnoreList(){
        PFPacketProcessor.ignoredCache.add(this.getPortUniqueId());
    }

    private void removeFromIgnoreList(){
        PFPacketProcessor.ignoredCache.remove(this.getPortUniqueId());
    }

    private void startTransaction(){
        PFPacketProcessor.transactionCache.add(sourceMac);
    }

    private void finishTransaction(){
        PFPacketProcessor.transactionCache.remove(sourceMac);
    }   

    private boolean shouldIgnorePacket(){
        return PFPacketProcessor.ignoredCache.contains(this.getPortUniqueId());
    }

    private boolean alreadyInTransaction(){
        return PFPacketProcessor.transactionCache.contains(sourceMac); 
    }

    private PacketResult handlePacketFenceResponse(JSONObject response){
        try{
            JSONArray result = response.getJSONArray("result");
            JSONObject data = result.getJSONObject(0); 
            String action = data.getString("action");
            if (action.equals("ignored")){
                this.addToIgnoreList();
            }
            else if(action.equals("isolate")){
                String method = data.getString("strategy");
                if(method.equals("DNS") && packet.getDestPort() == 53){
                    // do dns poisoning stuff
                    PFDNSPoison dnsPoison = new PFDNSPoison(this.packet, this.packetHandler);
                    dnsPoison.poisonFromPacket(); 
                    //this.forwardToPacketFence();
                    return PacketResult.CONSUME;
                }
                else if(method.equals("VLAN")){
                    // pf takes care of the flows here
                    return PacketResult.CONSUME;   
                }
                else{
                    return PacketResult.KEEP_PROCESSING;
                }
            }
            System.out.println(data.toString());
            log.debug(data.toString());
            return PacketResult.KEEP_PROCESSING;
        }
        catch(Exception e){
            e.printStackTrace();
            return PacketResult.KEEP_PROCESSING;
        } 
    }

    private void forwardToPacketFence(){
        
        try{
        this.packet.getL3Packet().setDestinationAddress(InetAddress.getByName(pfConfig.getElement("pf_dns_ip")));
        }catch(Exception e){e.printStackTrace();}
        System.out.println(this.packet.getDestIP());
        //this.packet.getL2Packet().setDestinationMACAddress(PF_MAC);
        NodeConnector outbound = NodeConnector.fromStringNoNode("1", this.packet.getRawPacket().getIncomingNodeConnector().getNode());
        RawPacket raw = packetHandler.getDataPacketService().encodeDataPacket(this.packet.getL2Packet());
        raw.setOutgoingNodeConnector(outbound);
        packetHandler.getDataPacketService().transmitDataPacket(raw);
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
            jsonBody.put("method", "sdn_authorize");
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

    private String getPortUniqueId(){
        return switchId + "-" + port;
    }
 
}
