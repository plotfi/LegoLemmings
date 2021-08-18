

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.InputStreamReader;
import java.io.IOException;
import java.net.Socket;
import java.util.StringTokenizer;
//import java.util.Vector;



/** The class regarding our server's thread. It extends thread
 * so it can utilize the actual threading that gets done,
 * making it easier for us. The threads pertain to individual
 * clients that connect to the server.
 */
public class NetServerThread extends Thread {

    /** socket connection */    
    private Socket socket = null;
    /** message out to server main then other users */    
    //private String message = null;
    /** message out */    
    private PrintWriter out;
    /** message in */    
    private BufferedReader in;
    /** user name */    
    private String userName;

    /** The constructor for the server's threading process.
     * @param socket The socket necessary for threading to take place.
     */    
    public NetServerThread(Socket socket) {
        super("NetServerThread");
        this.socket = socket;
    }

    /** The main function of our server threading class.
     * This reads the commands the users and the admin
     * supply as well as displays messages to the server.
     */    
    public void run() {

        try {
             
                String inputLine;
                StringTokenizer st;
                
                out = new PrintWriter(socket.getOutputStream(), true);
                in = new BufferedReader(new InputStreamReader(
                socket.getInputStream()));
                      
                inputLine = in.readLine();
                st = new StringTokenizer(inputLine);
                        
                if (st.hasMoreTokens()) {
                      
                    userName = st.nextToken();
                        
                } else {
                    
                        out.println("Good Bye...");
                        
                         out.close();
                         in.close();
                         socket.close();
                }
                    
                while ((inputLine = in.readLine()) != null) {
                        st = new StringTokenizer(inputLine);
                        sentMessage(inputLine);
                }
                out.close();
                in.close();
                socket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /** Sends a message to the server.
     * @param msg The message that needs to be sent to the server.
     */    
    public void sentMessage (String msg) {

        NetServer.broadcastMessage(msg);

    }

    /** Receives a message from the server and prints it out.
     * @param msg The message that the server receives.
     */        
    public void receiveMessage (String msg) {
if (null != out) {
        out.println(msg);
}

    }

}
