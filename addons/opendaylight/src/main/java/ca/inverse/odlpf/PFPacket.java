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
 

public class PFPacket {
    private Packet packet;
    private RawPacket rawPacket;
    private PacketHandler packetHandler;

    PFPacket(RawPacket rawPacket, PacketHandler packetHandler){
        this.packetHandler = packetHandler;
        this.rawPacket = rawPacket;
        this.packet = packetHandler.getDataPacketService().decodeDataPacket(this.rawPacket);
    }

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


    public Packet getL4Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            Object l3Pkt = ethFrame.getPayload();

            if (l3Pkt instanceof IPv4) {
                IPv4 ipv4Pkt = (IPv4) l3Pkt;
                //InetAddress clientAddr = intToInetAddress(ipv4Pkt.getSourceAddress());
                //InetAddress dstAddr = intToInetAddress(ipv4Pkt.getDestinationAddress());
                Object l4Datagram = ipv4Pkt.getPayload();

                if (l4Datagram instanceof UDP) {
                    UDP udpDatagram = (UDP) l4Datagram;
                    return udpDatagram;
                }
                else if(l4Datagram instanceof TCP){
                    TCP tcpDatagram = (TCP) l4Datagram;
                    return tcpDatagram;
                }
            }
        }       
        return null;
    }

    public IPv4 getL3Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            Object l3Pkt = ethFrame.getPayload();

            if (l3Pkt instanceof IPv4) {
                IPv4 ipv4Pkt = (IPv4) l3Pkt;
                return ipv4Pkt;
            }
        }
        return null;
    }

    public Ethernet getL2Packet(){
        if (this.packet instanceof Ethernet) {
            Ethernet ethFrame = (Ethernet) this.packet;
            return ethFrame;
        }
        return null;
    }

    public RawPacket getRawPacket(){
        return this.rawPacket;
    }

    public int getSourcePort(){
        Packet p = this.getL4Packet();
        if(p instanceof UDP){
            return ((UDP)p).getSourcePort();
        }
        else if(p instanceof TCP){
            return ((TCP)p).getSourcePort();
        }
        else{
            return 0;
        }
    }

    public int getDestPort(){
        Packet p = this.getL4Packet();
        if(p instanceof UDP){
            return ((UDP)p).getDestinationPort();
        }
        else if(p instanceof TCP){
            return ((TCP)p).getDestinationPort();
        }
        else{
            return 0;
        }
    }

    public String getSourceMac(){
        return HexEncode.bytesToHexStringFormat(this.getSourceMacBytes());
    }

    public String getDestMac(){
        return HexEncode.bytesToHexStringFormat(this.getDestMacBytes());
    }

    public byte[] getSourceMacBytes(){
        return this.getL2Packet().getSourceMACAddress();
    }

    public byte[] getDestMacBytes(){
        return this.getL2Packet().getDestinationMACAddress();
    }

    public String getSourceIP(){
        return this.getSourceInetAddress().toString();
    }

    public String getDestIP(){
        return this.getDestInetAddress().toString();
    }

    public InetAddress getSourceInetAddress(){
        return intToInetAddress(this.getL3Packet().getSourceAddress());
    }

    public InetAddress getDestInetAddress(){
        return intToInetAddress(this.getL3Packet().getDestinationAddress());
    }

    public NodeConnector getIncomingConnector(){
        return this.rawPacket.getIncomingNodeConnector();
    }

    public String getSourceInterface(){
        return this.getIncomingConnector().getNodeConnectorIDString();
    }


}
