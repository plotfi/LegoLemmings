

import java.awt.event.MouseListener;
import java.awt.event.MouseEvent;
import java.awt.event.KeyListener;
import java.awt.event.KeyEvent;
import java.awt.event.MouseMotionListener;

/**
 * This class watches the start screen for input.
 * This class watches the start screen for input.
 */
public class StartListener implements MouseListener, KeyListener,
                                      MouseMotionListener {

    /** The window to watch.*/
    private LemmingCanvas window;

    /** on the multiplayer screen*/
    private boolean inMulti = false;

    /** on the multiplayer host screen.*/
    private boolean inMultiHost = false;

    /** on the multiplayer client screen.*/
    private boolean inMultiClient = false;

    /** on the level selection screen.*/
    private boolean inSelect = false;

    /** on the level statistic screen.*/
    private boolean inStat = false;

    /** in the game.*/
    private boolean inFinal = false;

    /** typing in the host name */
    private boolean inHost = false;

    /** the selected level.*/
    private int choselvl = 0;

    /**
     * The constructor sets the canvas to watch.
     * The constructor sets the canvas to watch.
     *
     * @param in the canvas to watch.
     */
    public StartListener(LemmingCanvas in) {
        window = in;
    }

   /**
    * handles when the mouse is clicked.
    * handles when the mouse is clicked.
    *
    * @param e the mosue event.
    */
    public void mouseClicked(MouseEvent e) {
        int x = e.getX();
        int y = e.getY();
        int lvl;
        if (inMulti) {
            if (x > 298 && x < 352 && y > 188 && y < 202) {
                inMulti = false;
                inMultiHost = true;
                window.hostMulti();
            } else if (x > 298 && x < 382 && y > 218 && y < 232) {
                inMulti = false;
                inMultiClient = true;
                window.cnctMulti();
            }
        } else if (inMultiHost) {
            if (x > 250 && x < 350) {
                if ((lvl = (y - 200) / 20) >= 0
                    && lvl < window.getlChooser().getLevelCount()) {
                    window.previewLevel(lvl);
                    choselvl = lvl;
                }
            }
            if (x > 675 && x < 750 && y > 450 && y < 550) {
System.out.println("start");
                //start multiplayer.
                window.startMultiPlayerServer();
            }
        } else if (inMultiClient) {
            if (x > 50 && x < 150) {
                if ((lvl = (y - 200) / 20) >= 0
                    && lvl < window.getlChooser().getLevelCount()) {
                    window.previewLevel(lvl);
                    choselvl = lvl;
                }
            }
            if (x > 675 && x < 750 && y > 450 && y < 550) {
System.out.println("start Game");
                //start multiplayer.
                window.startMultiPlayerClient();
            }
        } else if (inFinal) {
            inFinal = false;
            inStat = true;
            window.levelStats(window.getNextLevel());
        } else if (inSelect) {
            if (x > 100 && x < 200) {
                if ((lvl = (y - 100) / 20) >= 0
                    && lvl < window.getlChooser().getLevelCount()) {
                    window.previewLevel(lvl);
                    choselvl = lvl;
                }
            }
            if (x > 698 && x < 768 && y > 485 && y < 505) {
                inSelect = false;
                inStat = true;
                window.levelStats(choselvl);
            }
        } else if (inStat) {
            inStat = false;
            inFinal = true;
            window.startLevel(window.getNextLevel());
        } else {
            if (x > 200 && x < 600) {
                if (y > 200 && y < 300) {
                    inStat = true;
                    window.levelStats(0);
                } else if (y > 300 && y < 400) {
                    window.chooseLevel();
                    inSelect = true;
                } else if (y > 400 && y < 500) {
                    window.setupMulti();
                    inMulti = true;
                }
            } //200-600
        } //else
    }

   /**
    * This function is only here to make Mouse Listener happy.
    * This function is only here to make Mouse Listener happy.
    *
    * @param e the mouse event.
    */
    public void mousePressed(MouseEvent e) {
    }

   /**
    * This function is only here to make Mouse Listener happy.
    * This function is only here to make Mouse Listener happy.
    *
    * @param e the mouse event.
    */
    public void mouseReleased(MouseEvent e) {
    }

   /**
    * This function is only here to make Mouse Listener happy.
    * This function is only here to make Mouse Listener happy.
    *
    * @param e the mouse event.
    */
    public void mouseEntered(MouseEvent e) {
    }

   /**
    * This function is only here to make Mouse Listener happy.
    * This function is only here to make Mouse Listener happy.
    *
    * @param e the mouse event.
    */
    public void mouseExited(MouseEvent e) {
    }

   /**
    * This function handles key input.
    * This function handles key input.
    *
    * @param e the key event.
    */
    public void keyTyped(KeyEvent e) {
        char temchar = e.getKeyChar();
        if (inMultiHost || (inMultiClient && !inHost)) {
            if (temchar > KeyEvent.VK_0 && temchar < KeyEvent.VK_9) { //number
                int temp = window.getPort();
                temp *= 10;
                temp += Character.getNumericValue(temchar);
                window.setPort(temp);
            } else if (temchar == KeyEvent.VK_BACK_SPACE) {
                window.setPort(window.getPort() / 10);
            } else if (temchar == KeyEvent.VK_ENTER) {
                inHost = true;
            }
        } else if (inMultiClient && inHost) {
            String tempS = window.getHost();
            if (temchar == KeyEvent.VK_ENTER) {
                inHost = false;
            } else if (temchar == KeyEvent.VK_BACK_SPACE) {
                tempS = tempS.substring(0, tempS.length() - 1);
            } else {
                tempS = tempS.concat(new Character(temchar).toString());
            }
            window.setHost(tempS);
        }
    }

   /**
    * This function is only here to make Key Listener happy.
    * This function is only here to make Key Listener happy.
    *
    * @param e the mouse event.
    */
    public void keyPressed(KeyEvent e) {
    }

   /**
    * This function is only here to make Key Listener happy.
    * This function is only here to make Key Listener happy.
    *
    * @param e the mouse event.
    */
    public void keyReleased(KeyEvent e) {
    }

   /**
    * This function is only here to make Mouse Motion Listener happy.
    * This function is only here to make Mouse Motion Listener happy.
    *
    * @param e the mouse event.
    */
    public void mouseDragged(MouseEvent e) {
    }

   /**
    * This function is only here to make Mouse Motion Listener happy.
    * This function is only here to make Mouse Motion Listener happy.
    *
    * @param e the mouse event.
    */
    public void mouseMoved(MouseEvent e) {
    }

}
