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
import org.opendaylight.controller.sal.packet.TCP;
import org.opendaylight.controller.sal.packet.UDP;
import org.opendaylight.controller.sal.packet.Packet;
import org.opendaylight.controller.sal.packet.PacketResult;
import org.opendaylight.controller.sal.packet.RawPacket;
import org.opendaylight.controller.sal.flowprogrammer.Flow;
import org.opendaylight.controller.sal.match.Match;
import org.opendaylight.controller.sal.utils.Status;
import org.opendaylight.controller.sal.match.MatchType;
import org.opendaylight.controller.sal.action.*;
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
import java.util.LinkedList;
import java.util.List;
import java.net.UnknownHostException;
 

public class PFDNSPoison {
    private static final Logger log = LoggerFactory.getLogger(PacketHandler.class);
    private static final PFConfig pfconfig = new PFConfig("/etc/packetfence.conf");
    private PFPacket packet;
    private PacketHandler packetHandler;
    //private static final byte[] PF_MAC = {(byte)0, (byte)80, (byte)86, (byte)157, (byte)0, (byte)11};
    private static final byte[] PF_MAC = pfconfig.getMacBytes(pfconfig.getElement("pf_dns_mac"));
    private static Hashtable<String,Flow> outboundFlows = new Hashtable<String,Flow>();
    private static Hashtable<String,Flow> inboundFlows = new Hashtable<String,Flow>();

    PFDNSPoison(PFPacket packet, PacketHandler packetHandler){
        this.packet = packet;
        this.packetHandler = packetHandler;
    } 

    /*
     * Installs the required flows to forward the DNS traffic to PacketFence
     */
    public void poisonFromPacket(){
        System.out.println("Installing DNS outbound redirect flow");
        this.poisonOutbound();
        System.out.println("Installing return flow");
        this.poisonInbound();
    }

    /*
     * Returns the outbound match based on the initial destination of the packet
     */
    private Match getOutboundMatch(){
        Match match = new Match();
        match.setField(MatchType.DL_TYPE, (short) 0x0800);  // IPv4 ethertype
        match.setField(MatchType.NW_PROTO, (byte) 17);  
        ////match.setField(MatchType.DL_SRC, packet.getSourceMacBytes());
        match.setField(MatchType.NW_DST, packet.getDestInetAddress());
        match.setField(MatchType.TP_SRC, (short) packet.getSourcePort());
        match.setField(MatchType.TP_DST, (short) packet.getDestPort());

        return match;
    }

    /*
     * Returns the actions to do on packet so it's forwarded to PacketFence
     * Rewrites the destination IP and MAC to the ones in the PacketFence configuration file on 
     *   the controller
     */
    private List getOutboundActions(){
        List actions = new LinkedList();
        try{
        actions.add( new SetNwDst( InetAddress.getByName(pfconfig.getElement("pf_dns_ip")) ) );
        }catch(Exception e){e.printStackTrace();}

        actions.add( new SetDlDst( PF_MAC ) ); 
        actions.add( new Flood() ); 

        return actions;
    }

    /*
     * Installs the flow to redirect the DNS queries to PacketFence
     */
    private void poisonOutbound(){
        this.installFlow(this.getOutboundMatch(), this.getOutboundActions());
    }

    /*
     * Returns the inbound match based on the new destination of the packet
     */
    private Match getInboundMatch(){
        Match match = new Match();
        match.setField(MatchType.DL_TYPE, (short) 0x0800);  // IPv4 ethertype
        match.setField(MatchType.NW_PROTO, (byte) 17);   
        ////match.setField(MatchType.DL_SRC, PF_MAC);

        try{
        match.setField(MatchType.NW_SRC, InetAddress.getByName(pfconfig.getElement("pf_dns_ip")) );
        }catch(Exception e){e.printStackTrace();}
        match.setField(MatchType.TP_SRC, (short) packet.getDestPort());
        match.setField(MatchType.TP_DST, (short) packet.getSourcePort());
    
        return match;
    }

    /*
     * Returns the actions to do on the packet that gets back 
     *   so it respects the initial destination of the packet
     * Rewrites the source IP to the one that the packet
     *   should have originally been sent to.
     */
    private List getInboundActions(){
        List actions = new LinkedList();
        try{
        actions.add( new SetNwSrc( packet.getDestInetAddress()  ) );
        }catch(Exception e){e.printStackTrace();}

        ////actions.add( new SetDlSrc( packet.getDestMacBytes() ) ); 
        actions.add( new Flood() ); 

        return actions;
    }

    /*
     * Installs the flow to rewrite the return packet so it looks like
     *   it came from the original destination
     */
    private void poisonInbound(){

        this.installFlow(this.getInboundMatch(), this.getInboundActions());
    }

    /*
     * Generic method for this class to install a flow based on a match
     *   and a list of actions
     */
    private void installFlow(Match match, List actions){
        Flow flow = new Flow(match, actions);
        flow.setPriority((short)1001);
        flow.setHardTimeout((short)5);
        Status status = packetHandler.getFlowProgrammerService().addFlow(packet.getIncomingConnector().getNode(), flow);
        if (!status.isSuccess()) {
            System.out.println("Could not program flow: " + status.getDescription());
        }
    }

}
