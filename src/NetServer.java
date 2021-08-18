

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Vector;
import java.util.List;

import java.util.StringTokenizer;


/** The backbone of the server. This class is the actual
 * server that listens for threads, broadcasts messages,
 * and opens the socket port.
 */
public class NetServer {

    
    /** This holds a list of all the users logged in. */    
    private static List users = new Vector();
    /** The port number*/
    private int port;
    /** The Socket*/
    private Socket sock;
    /** The server Scoket*/
    private ServerSocket serverSocket = null;

    /** the number dead*/
    private static String dead = "0";
    /** The number saved*/
    private static String sav = "0";
    /** the number out*/
    private static String out = "0";
    /** the number released*/
    private static String rel = "0";
    /** true if player wants to nuke.*/
    private static boolean nuke = false;
    /**the thread.*/
    private NetServerThread tmpthrd;
    
   /** 
    *sets the port 
    * @param portin the port.
    */
    public NetServer (int portin) {
        port = portin;
    }

    /**
     * This function starts the server.
     * This function starts the server.
     *
     * @throws IOException The exception that the main function can throw is
     * an Input/Output exception.
     */    
    public void start() throws IOException {

        try {
            serverSocket = new ServerSocket(port);
        } catch (IOException e) {
            System.err.println("Could not listen on port: " + port);
            System.exit(-1);
        }
        
        sock = serverSocket.accept();
        tmpthrd = new NetServerThread(sock);

        users.add(tmpthrd);

        tmpthrd.start();
        

    }

   /**
    * This function closes the connection.
    * This function closes the connection.
    */
    public void end() {
        try {
            serverSocket.close();
        } catch (IOException e) {
            System.exit(0);
        }
    }


    /** This function broadcasts messages in a server
     * so that all of the clients can read it.
     * @param msg The message that gets passed in to be broadcast to a server.
     */    
    public static void broadcastMessage(String msg) { 
        StringTokenizer st;
        String userName;
        st = new StringTokenizer(msg);
        userName = st.nextToken();
        if (st.hasMoreTokens()) {
            rel = st.nextToken();
        }
        if (st.hasMoreTokens()) {
            out = st.nextToken();
        }
        if (st.hasMoreTokens()) {
            sav = st.nextToken();
        }
        if (st.hasMoreTokens()) {
            dead = st.nextToken();
        }
        if (st.hasMoreTokens()) {
            nuke = true;
        } //nuke
    }

    /**the number dead
     * @return the number dead*/
    public String getdead() {
        return dead;
    }
    /** The number saved
     * @return the number saved.*/
    public String getsav() {
        return sav;
    }
    /** the number out
     * @return the number out.*/
    public String getout() {
        return out;
    }
    /** the number released
     * @return the number released.*/
    public String getrel() {
        return rel;
    }
    /** true if player wants to nuke.
     * @return true if the player wants to nuke.*/
    public boolean getnuke() {
        return nuke;
    }
    /**the thread.
     * @return the thread.
     */
    public NetServerThread gettmpthrd() {
       return tmpthrd;
    }
    /** the socket.
     * @return the socket.*/
    public Socket getsock() {
        return sock;
    }

}
