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
 
public class PacketHandler implements IListenDataPacket {
    private static final Logger log = LoggerFactory.getLogger(PacketHandler.class);
    private IDataPacketService dataPacketService;
 
    /*
     * Transforms an integer to an IP address
     */
    static private InetAddress intToInetAddress(int i) {
        byte b[] = new byte[] { (byte) ((i>>24)&0xff), (byte) ((i>>16)&0xff), (byte) ((i>>8)&0xff), (byte) (i&0xff) };
        InetAddress addr;
        try {
            addr = InetAddress.getByAddress(b);
        } catch (UnknownHostException e) {
            return null;
        }
 
        return addr;
    }
 
    /*
     * Sets a reference to the requested DataPacketService
     */
    void setDataPacketService(IDataPacketService s) {
        log.trace("Set DataPacketService.");
 
        dataPacketService = s;
    }
 
    /*
     * Unsets DataPacketService
     */
    void unsetDataPacketService(IDataPacketService s) {
        log.trace("Removed DataPacketService.");
 
        if (dataPacketService == s) {
            dataPacketService = null;
        }
    }
 
    /*
     * Executed when receiving a Packet
     * Will find the source mac, switch id and port number
     * Will then call informPacketFence to trigger the new connection events on PacketFence
     */
    @Override
    public PacketResult receiveDataPacket(RawPacket inPkt) {
        log.trace("Received data packet.");
 
        // The connector, the packet came from ("port")
        NodeConnector ingressConnector = inPkt.getIncomingNodeConnector();
        // The node that received the packet ("switch")
        Node node = ingressConnector.getNode();
 
        // Use DataPacketService to decode the packet.
        Packet l2pkt = dataPacketService.decodeDataPacket(inPkt);
 
        if (l2pkt instanceof Ethernet) {
            Object l3Pkt = l2pkt.getPayload();
            if (l3Pkt instanceof IPv4) {
                IPv4 ipv4Pkt = (IPv4) l3Pkt;
                int dstAddr = ipv4Pkt.getDestinationAddress();
                InetAddress addr = intToInetAddress(dstAddr);
                System.out.println("Pkt. to " + addr.toString() + " received by node " + node.getNodeIDString() + " on connector " + ingressConnector.getNodeConnectorIDString());
                String sourceMac = HexEncode.bytesToHexStringFormat(((Ethernet)l2pkt).getSourceMACAddress());
                String switchId = node.getNodeIDString();
                switchId = switchId.substring(0, 17);
                String port = ingressConnector.getNodeConnectorIDString();
                PFPacketProcessor pf = new PFPacketProcessor(sourceMac, switchId, port, l2pkt);
                return pf.processPacket(); 
            }
        }
        return PacketResult.IGNORED;
    }
    
}
