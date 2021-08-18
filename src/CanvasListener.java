

import java.awt.event.MouseListener;
import java.awt.event.MouseEvent;
import java.awt.event.KeyListener;
import java.awt.event.KeyEvent;
import java.awt.event.MouseWheelListener;
import java.awt.event.MouseWheelEvent;
import java.awt.event.MouseMotionListener;
import java.util.List;
import java.util.Stack;




/**
 * This class watches the Canvas for events.
 * This class watches the Canvas for events.
 */
public class CanvasListener implements MouseListener, KeyListener,
                                  MouseWheelListener, MouseMotionListener {

   /**
    * The Window.
    * the Level window being watched.
    */
    private Level window;

   /**
    * The Mouse's X position.
    * The mouse's X Position.
    */
    private int mx = 0;
   /** 
    * The Mouse's Y position.
    * The mouse's Y Position.
    */
    private int my = 0;

   /** 
    * The currently selected ability.
    * The currently selected ability.
    */
    private char selectedAbility = 'n';
/*n = none, b=blocker, e=exploder, d=digger, m=miner,
r=bridger, c=climber, f=floater, a=across digger(basher)
*/

   /**
    * The abilities available for this level, and their count.
    * The abilities available for this level, and their count.
    * -1 == no uses for this level.
    */ 
    private Stack abilLink;

   /**
    * the remaining uses of the digger ability.
    * the remaining uses of the digger ability.
    */
    private int digger;

   /**
    * the remaining uses of the blocker ability.
    * the remaining uses of the blocker ability.
    */
    private int blocker;

   /**
    * the remaining uses of the floater ability.
    * the remaining uses of the floater ability.
    */
    private int floater;

   /**
    * the remaining uses of the exploder ability.
    * the remaining uses of the exploder ability.
    */
    private int exploder;

   /**
    * the remaining uses of the bridger ability.
    * the remaining uses of the bridger ability.
    */
    private int bridger;

   /**
    * the remaining uses of the climber ability.
    * the remaining uses of the climber ability.
    */
    private int climber;

   /**
    * the remaining uses of the miner ability.
    * the remaining uses of the miner ability.
    */
    private int miner;

   /**
    * the remaining uses of the basher ability.
    * the remaining uses of the basher ability.
    */
    private int basher;
    

   /** 
    * The Constructor, sets up the window to listen to.
    * The Constructor, sets up the window to listen to.
    *
    * @param in The Canvas to listen to.
    * @param abilIn The available abilities, and their count.
    */
    public CanvasListener(Level in, Stack abilIn) {
        window = in;
        abilLink = abilIn;
        Stack abilInCpy = (Stack) abilLink.clone();
        Integer tempIntCnt = (Integer) abilInCpy.pop();
        digger = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        blocker = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        floater = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        exploder = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        bridger = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        climber = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        miner = tempIntCnt.intValue();
        tempIntCnt = (Integer) abilInCpy.pop();
        basher = tempIntCnt.intValue();
        
//add the array of lemmings/link to it?
    }


   /** 
    * This function watches for mouse clicks.
    * This function watches for mouse clicks, and does an appropriate 
    * action based on the position of the click.
    *
    * @param e the mouse event.
    */
    public void mouseClicked(MouseEvent e) {
        int yPos = e.getY();
        int xPos = e.getX();
        Lemming selectedLemming;
        List lemmings = window.getLemmings();

        if (window.getPaused()) {
            window.setPaused(false);
            return;
        }

        if (yPos < 35) {
            if ((xPos < 600) && (xPos > 500)) {
                window.displayHelp();
            } else if ((xPos > 600) && (xPos < 700)) {
                window.displayAbout();
            }
        } else if (yPos < 490) {
            for (int i = 0; i < lemmings.size(); i++) {
                selectedLemming = (Lemming) lemmings.get(i);

                if (lemmingSelected(xPos, yPos,
(int) (window.getScale() * selectedLemming.getXPos()
+ window.getScale() * window.getXOffset()),
(int) (window.getScale() * selectedLemming.getYPos()
+ window.getScale() * window.getYOffset()))) {
                    i = 10000;
                    switch (selectedAbility) {
                    case 'n':
                        break;
                    case 'b':
                        if (blocker > 0 && !selectedLemming.isBlocker()) {
                            selectedLemming.setBlocker(true);
                            blocker--;
                            abilLink.remove(6);
                            abilLink.insertElementAt(new Integer(blocker), 6);
                        }
                        break;
                    case 'e'://exploder
                        if (exploder > 0 && !selectedLemming.isExploder()) {
                            selectedLemming.setExploder(true);
selectedLemming.setExpTime((int) HiResTimer.getInstance()
            .currentTimeMillis());
                            exploder--;
                            abilLink.remove(4);
                            abilLink.insertElementAt(new Integer(exploder), 4);
                        }
                        break;
                    case 'd':
                        if (digger > 0 && !selectedLemming.isDigger()) {
                            selectedLemming.setDigger(true);
                            digger--;
                            abilLink.remove(7);
                            abilLink.insertElementAt(new Integer(digger), 7);
                        }
                        break;
                    case 'm'://miner
                         if (miner > 0 && !selectedLemming.isMiner()) {
                             selectedLemming.setMiner(true);
                             miner--;
                            abilLink.remove(1);
                            abilLink.insertElementAt(new Integer(miner), 1);
                         }
                        break;
                    case 'r'://bridger
                        if (bridger > 0 && !selectedLemming.isBridger()) {
                            selectedLemming.setBridger(true);
                            bridger--;
                            abilLink.remove(3);
                            abilLink.insertElementAt(new Integer(bridger), 3);
                        }
                        break;
                    case 'c'://climber
                        if (climber > 0 && !selectedLemming.isClimber()) {
                            selectedLemming.setClimber(true);
                            climber--;
                            abilLink.remove(2);
                            abilLink.insertElementAt(new Integer(climber), 2);
                        }
                        break;
                    case 'f'://floater
                        if (floater > 0 && !selectedLemming.isFloater()) {
                            selectedLemming.setFloater(true);
                            floater--;
                            abilLink.remove(5);
                            abilLink.insertElementAt(new Integer(floater), 5);
                        }
                        break;
                    case 'a': //basher
                        if (basher > 0 && !selectedLemming.isBasher()) {
                            selectedLemming.setBasher(true);
                            basher--;
                            abilLink.remove(0);
                            abilLink.insertElementAt(new Integer(basher), 0);
                        }
                        break;
                    default:
                        break;
                    } // switch
                } //if
            } //for
        } else {
            switch (xPos / 70) {
            case 10:
                break;
            case 9:
                if (yPos > 540) {
                    window.rateChange(1);
                } else {
                    window.rateChange(-1);
                } 
                break;
            case 8:
                for (int i = 0; i < lemmings.size(); i++) {
                    selectedLemming = (Lemming) lemmings.get(i);
                    selectedLemming.setExploder(true);
selectedLemming.setExpTime((int) HiResTimer.getInstance()
            .currentTimeMillis());
                }
                window.nukeEm();
                break;
            case 7:
                selectedAbility = 'a';
                break;
            case 6:
                selectedAbility = 'm';
                break;
            case 5:
                selectedAbility = 'c';
                break;
            case 4:
                selectedAbility = 'r';
                break;
            case 3:
                selectedAbility = 'e';
                break;
            case 2:
                selectedAbility = 'f';
                break;
            case 1:
                selectedAbility = 'b';
                break;
            case 0:
                selectedAbility = 'd';
                break;
            default:
                break;
            }
        }
    }

   /** 
    * This function is only present to make Mouse Listener happy.
    * This function is only present to make Mouse Listener happy.
    *
    * @param e the Mouse Event.
    */
    public void mousePressed(MouseEvent e) {
    }

   /** 
    * This function is only present to make Mouse Listener happy.
    * This function is only present to make Mouse Listener happy.
    *
    * @param e the Mouse Event.
    */
    public void mouseReleased(MouseEvent e) {
    }

   /** 
    * This function is only present to make Mouse Listener happy.
    * This function is only present to make Mouse Listener happy.
    *
    * @param e the Mouse Event.
    */
    public void mouseEntered(MouseEvent e) {
    }

   /** 
    * This function is only present to make Mouse Listener happy.
    * This function is only present to make Mouse Listener happy.
    *
    * @param e the Mouse Event.
    */
    public void mouseExited(MouseEvent e) {
    }


   /** 
    * This function is only present to make Key Listener happy.
    * This function is only present to make Key Listener happy.
    *
    * @param e the key Event.
    */
public void keyTyped(KeyEvent e) {
}

   /** 
    * This function does events based on key presses.
    * This function does events based on key presses.
    *
    * @param e the key Event.
    */
public void keyPressed(KeyEvent e) {
    Lemming selectedLemming;
    List lemmings = window.getLemmings();
    switch (e.getKeyCode()) {
    case KeyEvent.VK_P:
        window.setPaused(!(window.getPaused()));
        break;
    case KeyEvent.VK_S:
         for (int i = 0; i < lemmings.size(); i++) {
             selectedLemming = (Lemming) lemmings.get(i);
             selectedLemming.toggleSpeed();
         }
         window.toggleSpeed();
        break;
    case KeyEvent.VK_F1:
        window.zoom(2);
        break;
    case KeyEvent.VK_F2:
        window.zoom(.5);
        break;
    case KeyEvent.VK_UP:
        window.addYoff(5);
        break;
    case KeyEvent.VK_DOWN:
        window.addYoff(-5);
        break;
    case KeyEvent.VK_LEFT:
        window.addXoff((int) (5 * window.getScale()));
        break;
    case KeyEvent.VK_RIGHT:
        window.addXoff((int) (-5 * window.getScale()));
        break;
    case KeyEvent.VK_MINUS:
        window.rateChange(1);
        break;
    case KeyEvent.VK_EQUALS:
        window.rateChange(-1);
        break;
    default:
        break;

    }
}


   /** 
    * This function scrolls the window based on scrolling the mouse.
    * This function scrolls the window based on scrolling the mouse.
    *
    * @param e the mouse wheel Event.
    */
public void mouseWheelMoved(MouseWheelEvent e) {
    if (!e.isShiftDown()) {
        window.addYoff((int) (4 * window.getScale() * e.getWheelRotation()));
    } else {
         window.addXoff((int) (4 * window.getScale() * e.getWheelRotation()));
    }
}


   /** 
    * This function is only present to make Key Listener happy.
    * This function is only present to make Key Listener happy.
    *
    * @param e the key Event.
    */
    public void keyReleased(KeyEvent e) {
    }

   /** 
    * This function updates the mouse position.
    * This function updates the mouse position.
    *
    * @param e the mouse Event.
    */
    public void mouseDragged(MouseEvent e) {
        mx = e.getX();
        my = e.getY();
    }

   /** 
    * This function updates the mouse position.
    * This function updates the mouse position.
    *
    * @param e the mouse Event.
    */
    public void mouseMoved(MouseEvent e) {
        mx = e.getX();
        my = e.getY();
    }

   /** 
    * This function determines if the selected lemming.
    * This function determines if you are on the selected lemming.
    *
    * @param xin the x lemming position.
    * @param yin the y lemming position.
    *
    * @return whether or not you're on the selected lemming.
    */
    public boolean isChosen(int xin, int yin) {
        boolean ret = false;
        if (mx < (xin + (int) (40 * window.getScale())) && mx > xin) {
            if (my < (yin + (int) (40 * window.getScale())) && my > yin) {
                ret = true;
            }
        }
        return ret;
    }

   /** 
    * This function returns the currently selected ability.
    * This function returns the currently selected ability.
    *
    * @return the char value for the selected ability.
    */
    public char getAbility() {
        return selectedAbility;
    }

   /** 
    * This function figures out if you have selected the given lemming.
    * This function figures out if you have selected the given lemming.
    *
    * @param xcl the x Click.
    * @param ycl the y Click.
    * @param xlem the x lemming position.
    * @param ylem the y lemming position.
    *
    * @return whether or not you're on the selected lemming.
    */
    public boolean lemmingSelected(int xcl, int ycl, int xlem, int ylem) {
        boolean ret = false;

        if (xcl < (xlem + (int) (40 * window.getScale())) && xcl > xlem) {
            if (ycl < (ylem + (int) (40 * window.getScale())) && ycl > ylem) {
            ret = true;
            }
        }
        return ret;
    }

}
