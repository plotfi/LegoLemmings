

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.InputStreamReader;
import java.io.IOException;
import java.net.UnknownHostException;
import java.net.Socket;

/** This is the main server class, all threads for the serve are launched
 * from this class. Also, a server handler will me implemented from this class
 * or a thread this one spawns.
 */
public class NetClient {
    
    /** This is the server socket for the connection 
     between the client and the server. */    
    private static Socket clientSocket = null;
    /** out to server then to other users */    
    private static PrintWriter out = null;
    /** in from the server */    
    private static BufferedReader in = null;
    /** the user number*/
    private static int user;
    /** The port number*/
    private static int port;
    /** The host name*/
    private static String host;
    /** where to listen for messages*/
    private static NetClientThread listenForMsgs;
    /** true if serving*/
    private static boolean serving = false;
    /** reference to the server, if serving*/
    private static NetServer servref = null;

   /** 
    * This constructor sets variables 
    * This constructor sets variables 
    * 
    * @param userin the user number.
    * @param hostin the hostName.
    * @param portin the port.
    */
    public NetClient (int userin, String hostin, int portin) {
        user = userin;
        host = hostin;
        port = portin;
    }

   /**
    * This function starts the client in serving mode.
    * This function starts the client in serving mode.
    *
    * @param servin the Server.
    * @throws IOException sorry about that!
    */
    public static void start(NetServer servin) throws IOException {
        serving = true;
        clientSocket = servin.getsock();
        start();
        servref = servin;
    }
    
    /** 
     * This function starts the Client up.
     * This function starts the Client up.
     * @throws IOException yeah it does, for when you can't connect
     *                     to the server.
     */    
    public static void start() throws IOException {
        
        try {
            if (null == clientSocket) {
                clientSocket = new Socket(host, port);
            }
            out = new PrintWriter(clientSocket.getOutputStream(), true);
            in = new BufferedReader(
                new InputStreamReader(
                    clientSocket.getInputStream()));

            
        } catch (UnknownHostException e) {
            System.err.println("Don't know about host.");
            System.exit(1);
        } catch (IOException e) {
            System.err.println(
                "Couldn't get I/O for the connection to.");
            System.exit(1);
        }

        out.println(user);

        listenForMsgs = 
                new NetClientThread(clientSocket, in, user);
                
        listenForMsgs.start();
    
        

       
 
}
    
    
/** this sends string messages to the server. 
  *  which converts then into objects.
  *  @param msg this is the string message that gets sent
  */    
public static void send(String msg) {
    

    if (null != out) {   
        out.println(msg);
    }
                
}



 /**
  * this sends the statistics.
  * this sends the statistics.
  *
  * @param rel released.
  * @param outint number out.
  * @param sav number saved.
  * @param dead number dead.
  * @param nuke if true, want to nuke the level.
  */
    public static void sendStats(int rel, int outint, int sav, int dead,
                                 boolean nuke) {
// username released out saved dead nuke?

        String outTem = "1 " + rel + " " + outint + " " + sav + " " + dead;

        if (serving) {
            servref.gettmpthrd().receiveMessage(outTem);
        } else {
             if (null != out) { 
                 if (nuke) {
                     out.println(outTem + " YES");
                 } else {
                     out.println(outTem);
                 }
             }
         } //serving
    }

   /**
    * This function returns the number released
    *
    * @return the number released
    */
    public int getReleased() {
        if (null == listenForMsgs) {
            return 0;
        }
        if (serving) {
            return Integer.parseInt(servref.getrel());
        }
        return Integer.parseInt(listenForMsgs.getrel());
    }

   /**
    * This function returns the number out
    *
    * @return the number out
    */
    public int getOut() {
        if (null == listenForMsgs) {
            return 0;
        }
        if (serving) {
            return Integer.parseInt(servref.getout());
        }
        return Integer.parseInt(listenForMsgs.getout());
    }

   /**
    * This function returns the number saved
    *
    * @return the number saved
    */
    public int getSaved() {
        if (null == listenForMsgs) {
            return 0;
        }
        if (serving) {
            return Integer.parseInt(servref.getsav());
        }
        return Integer.parseInt(listenForMsgs.getsav());
    }

   /**
    * This function returns the number dead
    *
    * @return the number dead
    */
    public int getDead() {
        if (null == listenForMsgs) {
            return 0;
        }
        if (serving) {
            return Integer.parseInt(servref.getdead());
        }
        return Integer.parseInt(listenForMsgs.getdead());
    }

   /**
    * This function returns the nuke command
    *
    * @return true if the other player wants to nuke the level.
    */
    public boolean getNuke() {
        if (null == listenForMsgs) {
            return false;
        }
        if (serving) {
            return servref.getnuke();
        }
        return listenForMsgs.getnuke();
    }
       
    
}
