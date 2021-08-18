

import java.awt.Frame;
import java.awt.Color;
import java.awt.image.BufferStrategy;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;

import java.util.List;
import java.util.Vector;
import java.util.Stack;






/**
 * This class makes the Window of execution.
 * This class makes the Window of execution.
 */
public class Level implements Runnable {
    
    
    
    /**the frame we are going to draw the lemmings on*/
    private Frame frame;
    
  
   /**
    * The List of lemmings.
    * The List of lemmings.
    */
    private List lemmings = new Vector();
   
   /**
    * The background image.
    * The background image.
    */
    private BufferedImage bgImage;
   
    
   /**
    * The image mask.
    * The image mask.
    */
    private BufferedImage mask;

   /**
    * The image of buttons.
    * The image of buttons.
    */
    private BufferedImage buttons;
    
    /**buffer strategy controlling the draw*/
    private BufferStrategy bufferStrategy;
    
    /**the thread controlling the movement of all the balls*/
    private Thread thread;
    
    /**boolean indicating the thread is running*/
    private boolean running = true;

    /** boolean indicating the thread is paused.*/
    private boolean isPaused = false;

    /** boolean indicating the user wants to see the help screen.*/
    private boolean showHelp = false;

    /** boolean indicating the user wants to see the about screen.*/
    private boolean showAbout = false;

    /** boolean indicating the game is in multiplayer mode.*/
    private boolean isMulti;

    /** boolean indicating the user wants to nuke all their lemmings*/
    private boolean nuke = false;

    /** The Listener*/
    private CanvasListener listener;   

    /** the offset of the image in the x direction*/
    private int xoffset = 0;

    /** the offset of the image in the y direction*/
    private int yoffset = 0;

    /** the x starting point*/
    private int xstrt = 230;

    /** the y starting point*/
    private int ystrt = 200;

    /** the release rate*/
    private int rrate = 50;

    /** The maximum number of lemmings for this level.*/
    private int maxLem;

    /** How much time you have to beat the level. */
    private int levelTime;

    /** How many lemmings you need to save.*/
    private int toSave;

    /** How many lemmings you have saved.*/
    private int saved = 0;

    /** the window to animate on.*/
    private LemmingCanvas watched;

    /** The name of the level.*/
    private String levelName;

    /** 
     * The abilities available for this level, 
     * and the number of uses for each.
     */
    private Stack abilityData;

    /** The client to pass info to, in multiplayer games. */
    private NetClient netInfo;

    /** the scaler*/
    private double scale;

    /**speed toggler*/
    private boolean speed = false;


    
    /**
     * The Constructor.
     * The Constructor sets up the window for viewing.
     *
     * @param watchedin the Canvas that started this game.
     * @param inframe the frame to animate on.
     * @param data the data for the level.
     * @param xinitoff the initial offset in the x direction.
     * @param yinitoff the initial offset in the y direction.
     * @param abinfo the list of abilities for this level.
     * @param inNet The network client.
     */
    public Level(LemmingCanvas watchedin, Frame inframe, LevelData data,
               int xinitoff, int yinitoff,
               Stack abinfo, NetClient inNet) {

        watched = watchedin;
        frame = inframe;
        toSave = data.getGoal();
        maxLem = data.getCount();
        xoffset = xinitoff;
        yoffset = yinitoff;
        xstrt = (int) data.getStart().getX();
        ystrt = (int) data.getStart().getY();
        rrate = 100 - data.getRate();
        levelTime = data.getTime() * 60000;
        levelName = data.getFile();
        abilityData = abinfo;
        netInfo = inNet;
        if (null == netInfo) {
            isMulti = false;
        } else {
            isMulti = true;
        }
        
        listener = new CanvasListener(this, abilityData);
        frame.addMouseListener(listener);
        frame.addMouseWheelListener(listener);
        frame.addMouseMotionListener(listener);
        
        frame.addWindowListener(new WindowAdapter() {

              
            public void windowClosing(WindowEvent we) {
                isPaused = false;
                running = false;
            }

        
        });


        frame.addKeyListener(listener);
        
        try {


            frame.setIconImage(javax.imageio.ImageIO.read(
                                     getClass().getResource("lemIcon.png")));

            
             bgImage = 

                javax.imageio.ImageIO.read(
                              getClass().getResource(levelName + ".png"));
   
            mask = 
                javax.imageio.ImageIO.read(
                              getClass().getResource(levelName + "mask.png"));
               
            buttons = 
                javax.imageio.ImageIO.read(
                              getClass().getResource("toolbar.png"));
               
        } catch (Exception e) {
                System.err.println("Error: level not found..." + getClass().getResource("lemIcon.png"));
                System.err.println("Please Reload all game files.");
                System.exit(-1);
        }

        scale = 1;
        
        frame.createBufferStrategy(2);
        bufferStrategy = frame.getBufferStrategy();       
       

        Graphics g = bufferStrategy.getDrawGraphics();     
        Graphics2D g2 = (Graphics2D) g;
        g2.drawImage(bgImage, xoffset, yoffset, frame);

        thread = new Thread(this);
        thread.start();
        
    } 
    
  
  
   /**
    * This method does animation.
    * The run method handles image all animation.
    */
    public void run() {
        long currentTime = HiResTimer.getInstance().currentTimeMillis();
        int newLem = -1;
        long startTime = currentTime;
        long difTime;
        long timeString;
        long pauseTime = 0;
        int lemCount = 0;
        int currCount = 0;
        int mxoff = 695;
        int myh = mask.getHeight() / (mask.getWidth() / 100);
        int myoff = 595 - myh;
        Graphics g = bufferStrategy.getDrawGraphics();     
        Graphics2D g2 = (Graphics2D) g;
        Lemming currentLemming;
        while (running) {
            if (isPaused) {
                pauseTime = currentTime;
            }
            while (isPaused) {
                isPaused = true;
            }
            if (0 != pauseTime) {
                currentTime = HiResTimer.getInstance().currentTimeMillis();
                startTime += (currentTime - pauseTime);
                pauseTime = 0;
            }
            difTime = (currentTime - startTime);
            if (lemCount < maxLem && !nuke) {
                if (newLem < (difTime / (rrate * 100))) {
                    newLem = (int) difTime / (rrate * 100);
                   Lemming tempLem = new Lemming(xstrt, ystrt, mask, bgImage);
                    lemmings.add(tempLem);
                    lemCount++;
                    currCount++;
                    if (speed) {
                        tempLem.toggleSpeed();
                    }
                }
            }
            if (0 >= (levelTime - difTime)) {
                running = false;
            }
            if (currCount == 0 && lemCount >= maxLem) {
                running = false;
            }
            if (nuke && currCount == 0) {
                running = false;
            }
            int txoffset = (int) (xoffset * scale);
            int tyoffset = (int) (yoffset * scale);
            g2.setColor(Color.BLUE);
            g2.fillRect(0, 0, 800, 600);
            g2.drawImage(bgImage, txoffset, tyoffset, 
(int) (scale * bgImage.getWidth()), (int) (scale * bgImage.getHeight()), null);
            boolean chosen = false;
            for (int i = 0; i < lemmings.size(); i++) {

                currentLemming = (Lemming) lemmings.get(i); 
                currentLemming.updateImage();
                int xtem = (int) (currentLemming.getXPos() * scale + txoffset);
                int ytem = (int) (currentLemming.getYPos() * scale + tyoffset);
                g2.drawImage(currentLemming.getCurImage(), xtem, ytem, 
             (int) (currentLemming.getCurImage().getWidth() * scale),
             (int) (currentLemming.getCurImage().getHeight() * scale), null);
                if (currentLemming.isExploder()) {
                    g2.setColor(Color.RED);
            int timeLeft = (int) (currentTime - currentLemming.getExpTime());
                    timeLeft /= 1000;
                    timeLeft = 5 - timeLeft;
                    if (timeLeft < 0) {
                        timeLeft = 0;
                    }
                    g2.drawString("" + timeLeft, xtem + 15, ytem - 5);
                    if (timeLeft <= 0) {
                        currentLemming.setExplodeDie(true);
                    }
                }
                if (currentLemming.getDead()) {
                    lemmings.remove(currentLemming);
                    currCount--;
                }
                if (currentLemming.exited()) {
                    lemmings.remove(currentLemming);
                    saved++;
                    currCount--;
                }
                if (!chosen && listener.isChosen(xtem, ytem)) {
                    g2.setColor(Color.GREEN);
            g2.drawRect(xtem, ytem, (int) (40 * scale), (int) (40 * scale));
                    chosen = true;
                }
                currentLemming.move();
                currentTime = HiResTimer.getInstance().currentTimeMillis();
            }
            g2.setColor(Color.BLUE); //the mini-map
            g2.fillRect(0, 490, 800, 200);
            g2.drawImage(mask, mxoff, myoff, 100, myh, null);
            g2.setColor(Color.GREEN); //the area of the map looked at.
         g2.drawRect((int) (mxoff - txoffset * 100 / scale / mask.getWidth()),
               (int) (myoff - (tyoffset - 50) * myh / scale / mask.getHeight()),
                        (int) (800 * 100 / scale / mask.getWidth()),
                        (int) (440 * myh / scale / mask.getHeight()));
            g2.setColor(Color.YELLOW); //the lemmings, on the mini-map
            for (int j = 0; j < lemmings.size(); j++) {
                currentLemming = (Lemming) lemmings.get(j);
     g2.fillOval(currentLemming.getXPos() * 100 / mask.getWidth() + mxoff,
    (currentLemming.getYPos() + 10) * myh / mask.getHeight() + myoff, 2, 2);
            }
            g2.drawImage(buttons, 0, 490, mxoff, 100, null); //ability tool bar
            int abbx = -50; //draw a box around the selected ability.
            switch (listener.getAbility()) {
            case 'd':
                abbx = 0;
                break;
            case 'b':
                abbx = 70;
                break;
            case 'f':
                abbx = 140;
                break;
            case 'e':
                abbx = 210;
                break;
            case 'r':
                abbx = 280;
                break;
            case 'c':
                abbx = 350;
                break;
            case 'm':
                abbx = 420;
                break;
            case 'a':
                abbx = 490;
                break;
            default:
                break;
            }
            if (abbx >= 0) {
                g2.drawRect(abbx, 490, 70, 100);
            }
//for each ability, show the uses remaining. (or color over if unusable)
            Stack tempAbilStack = (Stack) abilityData.clone();
            for (int q = 0; q < 8; q++) {
                Integer tempInt = (Integer) tempAbilStack.pop();
                if (-1 == tempInt.intValue()) {
                    g2.setColor(Color.BLUE);
                    g2.fillRect(q * 70, 490, 70, 100);
                    g2.setColor(Color.BLACK);
                    g2.drawRect(q * 70, 490, 70, 100);
                } else {
                    g2.setColor(Color.GREEN);
                    g2.drawString("" + tempInt.intValue(), q * 70 + 25, 590);
                }
            }
            g2.setColor(Color.BLUE);
            g2.fillRect(0, 0, 800, 50);
            g2.setColor(Color.RED);
            timeString = (levelTime - difTime + 1000) / 1000;
            g2.drawString(" " + timeString / 60 + ":"
                             + (timeString % 60) / 10
                             + (timeString % 60) % 10,
                             750, 35);
            g2.drawString("release rate: " + (100 - rrate), 10, 35);
            g2.drawString("released: " + lemCount, 150, 35);
            g2.drawString("escaped %: " + saved * 100 / maxLem, 250, 35); 
            g2.drawString("in level: " + currCount, 350, 35);
            g2.setColor(Color.GREEN);
            g2.drawString("|      help      |", 500, 35);
            g2.drawString("|      about     |", 600, 35);
            if (isMulti) {
                g2.setColor(Color.GREEN);
                g2.fillRect(0, 40, 800, 30);
                g2.setColor(Color.RED);
                g2.drawString("released: " + netInfo.getReleased(), 150, 60);
                g2.drawString("in level: " + netInfo.getOut(), 350, 60);
                g2.drawString("saved: " + netInfo.getSaved(), 250, 60);
                g2.drawString("dead: " + netInfo.getDead(), 450, 60);
                netInfo.sendStats(lemCount, currCount, saved,
                                  lemCount - currCount, false);
            }
            if (showAbout) {
                drawAbout();
            }
            if (showHelp) {
                drawHelp();
            }
            bufferStrategy.show();           

              try {
                Thread.sleep(100);
              } catch (Exception e) {

              }
        } //end while
        frame.removeMouseListener(listener);
        frame.removeMouseWheelListener(listener);
        frame.removeMouseMotionListener(listener);
        frame.removeKeyListener(listener);
        if (isMulti) {
            watched.multiLevelFinished();
        } else {
            watched.levelFinished();
        }
     } //end start
     
     
   /**
    * This function sets the paused variable.
    * this function pauses the game.
    *
    * @param in true = pause the game.
    */
    public void setPaused(boolean in) {
        isPaused = in;
    }

   /**
    * this function tells you if the game is paused.
    * this function returns the paused variable.
    *
    * @return true if the game is paused.
    */
    public boolean getPaused() {
        return isPaused;
    }

   /**
    * this function moves the image in the X direction.
    * this function adds a displacement to the image.
    *
    * @param in how far to displace it.
    */
    public void addXoff(int in) {
        xoffset += in;
    }

   /**
    * this function moves the image in the Y direction.
    * this function adds a displacement to the image.
    *
    * @param in how far to displace it.
    */
    public void addYoff(int in) {
        yoffset += in;
    }
    
   /**
    * This function returns the height of the frame.
    * this function returns the height of the frame.
    *
    * @return  the height of the frame.
    */
    public int getFrameHeight() {
        return frame.getHeight();
    }

   /**
    * This function returns the list of lemmings.
    * This function returns the List of lemmings.
    *
    * @return the list of lemmings.
    */
    public List getLemmings() {
        return lemmings;
    }

   /**
    * This function returns the X offset.
    * this function returns the X offset.
    *
    * @return the X offset.
    */
    public int getXOffset() {
        return xoffset;
    }

   /**
    * This function returns the Y offset.
    * this function returns the Y offset.
    *
    * @return the Y offset.
    */
    public int getYOffset() {
        return yoffset;
    }

   /**
    * This function changes the rate of release.
    * This function adds a given input to the rate of release,
    * while keeping it in the bounds of 1-99.
    *
    * @param in the ammount to add to the rate.
    */
    public void rateChange(int in) {
        rrate += in;
        if (rrate > 99) {
            rrate = 99;
        }
        if (rrate < 1) {
            rrate = 1;
        }
    }


   /**
    * This function displays the help screen.
    * This function displays the help screen.
    */
    public void displayHelp() {
        showHelp = true;
    }

   /**
    * This function draws the help screen.
    * This function draws the help screen.
    */
    public void drawHelp() {
        Graphics g = bufferStrategy.getDrawGraphics();     
        Graphics2D g2 = (Graphics2D) g;
        showHelp = false;
        isPaused = true;
        g2.setColor(Color.BLUE);
        g2.fillRect(300, 50, 500, 340);
        g2.setColor(Color.RED);
        g2.drawString("Welcome to Lego Brand Lemmings!", 305, 60);
        g2.drawString("The goal of this game is to save all of the "
            + "lemmings.", 305, 90);
        g2.drawString("The tool bar above includes information on "
          + "how many lemmings have been saved,", 305, 105);
        g2.drawString("how many are left to save, and how much time "
          + "is left to save them in.", 305, 120);
        g2.drawString("The tool bar at the bottom allows you to "
          + "select abilities to give the lemmings,", 305, 135);
        g2.drawString("as well as the ability to increase their "
          + "release rate and a mini-map of the level.", 305, 150);
        g2.drawString("To give a lemming an ability, select the "
          + "ability, and then select the lemming you", 305, 165);
        g2.drawString("want to have that ability. ", 305, 180);
        g2.drawString("Beware: you have a limited number of uses "
         + "for each ability.", 305, 195);
        g2.drawString("Keys:", 305, 220);
        g2.drawString("'p' pauses/unpauses the game.", 305, 235);
        g2.drawString("'s' speeds up the rate of movement.", 305, 250);
        g2.drawString("'-'/'=' decrease/ increase the rate of "
         + "release of the lemmings.", 305, 265);
        g2.drawString("the arrow keys, and the mouse scroll wheel*, "
         + "scroll the level.", 305, 280);
        g2.drawString("'F1' / 'F2' zoom in and out.", 305, 295);
        g2.drawString("*normally the level scrolls with the wheel, "
         + "but by holding down the shift key, ", 305, 325);
        g2.drawString("it instead scrolls left/right.", 305, 340);
        g2.drawString("hit 'p' to continue game.", 305, 370);
    }

   /**
    * This function displays the about screen.
    * This function displays the about screen.
    */
    public void displayAbout() {
        showAbout = true;
    }

   /**
    * This function draws the About Screen.
    * This function draws the About Screen.
    */
    public void drawAbout() {
        Graphics g = bufferStrategy.getDrawGraphics();     
        Graphics2D g2 = (Graphics2D) g;
        showAbout = false;
        isPaused = true;
        g2.setColor(Color.BLUE);
        g2.fillRect(500, 50, 300, 120);
        g2.setColor(Color.RED);
        g2.drawString("Lego Lemmings", 505, 60);
        g2.drawString("Our Team Consists of:", 505, 80);
        g2.drawString("Joseph Earle", 505, 95);
        g2.drawString("--", 605, 95);
        g2.drawString("gtg210b", 655, 95);
        g2.drawString("David Figlar", 505, 125);
        g2.drawString("--", 605, 110);
        g2.drawString("gtg247i", 655, 125);
        g2.drawString("Puyan Lotfi", 505, 110);
        g2.drawString("--", 605, 125);
        g2.drawString("gtg945h", 655, 110);
        g2.drawString("Freddy Stroud", 505, 140);
        g2.drawString("--", 605, 140);
        g2.drawString("gtgg833a", 655, 140);
        g2.drawString("hit 'p' to continue game.", 505, 160);
    }

   /** 
    * whether or not the game is still running.
    * whether or not the game is still running.
    *
    * @return true if the game is running.
    */
    public boolean isRunning() {
        return running;
    }

   /**
    * This function returns the number of saved lemmings.
    * This function returns the number of saved lemmings.
    *
    * @return the number of saved lemmings.
    */
    public int getSaved() {
        return saved;
    }

   /**
    * This function says the user wants to nuke his lemmings.
    * This function says the user wants to nuke his lemmings.
    */
    public void nukeEm() {
        nuke = true;
    }

   /**
    * This function zooms the window.
    * This function zooms the window.
    *
    * @param scalemult how much to scale.
    */
    public void zoom(double scalemult) {
        scale *= scalemult;
    }

   /**
    * This function returns the current scalara multiplier.
    * This function returns the current scalara multiplier.
    *
    * @return the multiplyer.
    */
    public double getScale() {
        return scale;
    }

   /**
    * Toggles Speed.
    * Toggles Speed.
    */
    public void toggleSpeed() {
        speed = !speed;
    }

} 
