

import java.io.BufferedReader;
import java.io.IOException;
import java.net.Socket;
import java.util.StringTokenizer;

/** This class mainly exists to listen for incomming messages. */
public class NetClientThread extends Thread {

    /** socket connection to server */    
    private Socket socket = null;
    /** in from the server, separate thread listens for this */    
    private BufferedReader in = null;
    /** the user number*/
    private int user;
    /** The number released*/
    private String rel = "0";
    /** The number out*/
    private String out = "0";
    /** the number saved*/
    private String sav = "0";
    /**the number dead*/
    private String dead = "0";
    /** whether or not to nuke*/
    private boolean nuke = false;

    

    /** 
      * This is the thread that listens for in comming messages.
      * 
      * @param socket this is the socket connection to the server
      * @param in this is the input stream from the server
      * @param userIn the user making the connection.
      *
      */

        public NetClientThread(Socket socket, BufferedReader in, int userIn) {
            super("NetClientThread");
            this.socket = socket;
            this.in = in;
            user = userIn;
        }

    /** runs the client */    
    public void run() {
            StringTokenizer st;
            //String tmpCmd;
            try {
                        String fromServer;
                        String userName;
                        while ((fromServer = in.readLine()) != null) {
                            st = new StringTokenizer(fromServer);
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
                        } //while


            } catch (IOException e) {
                e.printStackTrace();
            }

    }

    /** The number released
     * @return the number released*/
    public String getrel() {
        return rel;
    }
    /** The number out
     * @return the number out.*/
    public String getout() {
        return out;
    }
    /** the number saved
     * @return the number saved.*/
    public String getsav() {
        return sav;
    }
    /**the number dead
     * @return the number dead.*/
    public String getdead() {
        return dead;
    }
    /** whether or not to nuke
     * @return whether or not to nuke*/
    public boolean getnuke() {
        return nuke;
    }

} // username released out saved dead nuke?
