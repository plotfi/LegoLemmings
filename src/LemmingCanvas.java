import java.awt.Color;
import java.awt.Font;
import java.awt.Frame;
import java.awt.Graphics;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.image.BufferStrategy;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.Stack;

/** This class makes the Window of execution. This class makes the Window of execution. */
public class LemmingCanvas {

  /** the frame we are going to draw the lemmings on */
  private Frame frame;

  /** buffer strategy controlling the draw */
  private BufferStrategy bufferStrategy;

  /** The Listener */
  private StartListener slistener;

  /** the Level to run in this window. */
  private Level runLevel;

  /** the levels to choose from */
  private LevelChooser lchooser;

  /** the number of the current level. */
  private int nextLevel = 0;

  /** the port to connect to. */
  private int port = 0;

  /** the host to connect to. */
  private String hostName = "";

  /** The Constructor. The Constructor sets up the window for viewing. */
  public LemmingCanvas() {

    lchooser = new LevelChooser();
    frame = new Frame("Lego Lemmings!!!");
    frame.setSize(800, 600);
    frame.setResizable(false);
    frame.setVisible(true);

    slistener = new StartListener(this);
    frame.addMouseListener(slistener);
    frame.addMouseMotionListener(slistener);
    frame.addKeyListener(slistener);

    Lemming initLemming = new Lemming();

    initLemming.init();

    frame.addWindowListener(
        new WindowAdapter() {
          public void windowClosing(WindowEvent we) {
            System.exit(0);
          }
        });

    frame.createBufferStrategy(2);
    bufferStrategy = frame.getBufferStrategy();

    Graphics g = frame.getGraphics();

    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.BOLD, 20));
    g.drawString("WELCOME TO LEGO LEMMINGS!!!!", 200, 100);
    g.setFont(new Font(null, Font.PLAIN, 16));
    g.drawString("Start Game", 300, 250);
    g.drawString("Choose Level", 300, 350);
    g.drawString("MulitPlayer Game", 300, 450);
    g.drawRect(200, 200, 400, 100);
    g.drawRect(200, 300, 400, 100);
    g.drawRect(200, 400, 400, 100);

    //        bufferStrategy.show();
  }

  /**
   * This screen shows the statistics for the next level.
   *
   * @param lvlNum the level to show stats for.
   */
  public void levelStats(int lvlNum) {

    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.BOLD, 20));

    if (lvlNum >= lchooser.getLevelCount()) {
      g.drawString("GAME OVER, MAN!!!", 300, 50);
      try {
        wait(5000);
      } catch (Exception e) {
        System.out.println("GAME OVER, MAN!!!");
        System.exit(0);
      }
      System.exit(0);
    }
    Stack sort = (Stack) lchooser.getLevelData(lvlNum).getAbilityData().clone();

    nextLevel = lvlNum;
    g.drawString("On To Level " + (nextLevel + 1), 300, 50);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("Digger: " + sort.pop(), 300, 100);
    g.drawString("Blocker: " + sort.pop(), 300, 120);
    g.drawString("Floater: " + sort.pop(), 300, 140);
    g.drawString("Exploder: " + sort.pop(), 300, 160);
    g.drawString("Bridger: " + sort.pop(), 300, 180);
    g.drawString("Climber: " + sort.pop(), 300, 200);
    g.drawString("Miner: " + sort.pop(), 300, 220);
    g.drawString("Basher: " + sort.pop(), 300, 240);
    int needed = lchooser.getLevelData(nextLevel).getGoal();
    int maxLem = lchooser.getLevelData(nextLevel).getCount();
    g.drawString("% you need to save: " + needed * 100 / maxLem, 275, 275);
  }

  /**
   * Host or connect? this function shows the screen where you pick either to host or connect to a
   * multiplayer game.
   */
  public void setupMulti() {
    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.BOLD, 20));
    g.drawString("Multi-Player Game", 300, 50);
    g.setFont(new Font(null, Font.BOLD, 18));
    g.drawString("Please Select if you will be hosting or connecting.", 200, 100);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("Hosting", 300, 200);
    g.drawString("Connecting", 300, 230);
    g.drawRect(298, 188, 54, 14);
    g.drawRect(298, 218, 84, 14);
  }

  /**
   * this function shows the window for starting a multiplayer game. this function shows the window
   * for starting a multiplayer game.
   */
  public void hostMulti() {
    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.BOLD, 20));
    g.drawString("Multi-Player Game", 300, 50);
    g.setFont(new Font(null, Font.BOLD, 18));
    g.drawString("Please Select Port Number and Level.", 200, 100);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("PORT : " + port, 250, 150);
    g.drawRect(248, 135, 100, 20);
    for (int i = 0; i < lchooser.getLevelCount(); i++) {
      g.drawString(lchooser.getLevelData(i).getFile(), 250, 210 + 20 * i);
    }
    g.drawString("Start", 700, 500);
    g.drawRect(675, 450, 75, 100);
  }

  /**
   * this function shows the window for connecting to a multiplayer game. this function shows the
   * window for connecting to a multiplayer game.
   */
  public void cnctMulti() {
    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.BOLD, 20));
    g.drawString("Multi-Player Game", 300, 50);
    g.setFont(new Font(null, Font.BOLD, 18));
    g.drawString("Please Select Port Number and Level.", 200, 100);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("PORT : " + port, 250, 150);
    g.drawString("HOST: " + hostName, 250, 200);
    g.drawRect(248, 135, 100, 20);
    g.drawRect(248, 185, 300, 20);
    for (int i = 0; i < lchooser.getLevelCount(); i++) {
      g.drawString(lchooser.getLevelData(i).getFile(), 50, 210 + 20 * i);
    }
    g.drawString("Start", 700, 500);
    g.drawRect(675, 450, 75, 100);
  }

  /** after the level, show if you won or lost. after the level, show if you won or lost. */
  public void levelFinished() {
    frame.addMouseListener(slistener);
    frame.addMouseMotionListener(slistener);
    frame.addKeyListener(slistener);

    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    // show stats, check to see if proceed to next level.
    int rescued = runLevel.getSaved();
    int needed = lchooser.getLevelData(nextLevel).getGoal();
    int maxLem = lchooser.getLevelData(nextLevel).getCount();

    g.drawString("% Lemmings Saved: " + rescued * 100 / maxLem, 300, 400);

    g.setFont(new Font(null, Font.BOLD, 24));
    if (rescued >= needed) {
      g.drawString("CONGRATULATIONS!!!", 200, 100);
      g.drawString("LEVEL " + ++nextLevel + " BEATEN", 200, 200);
    } else {
      g.drawString("LEVEL FAILED", 200, 100);
    }
    g.setFont(new Font(null, Font.PLAIN, 12));
  }

  /** select a level. select a level. */
  public void chooseLevel() {

    Graphics g = frame.getGraphics();

    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    for (int i = 0; i < lchooser.getLevelCount(); i++) {
      g.drawString(lchooser.getLevelData(i).getFile(), 100, 110 + 20 * i);
    }
    g.drawString("Load Level", 700, 500);
    g.drawRect(698, 485, 70, 20);
  }

  /**
   * run a given level. run a given level.
   *
   * @param lvlNum the level to start.
   */
  public void startLevel(int lvlNum) {
    frame.removeMouseListener(slistener);
    frame.removeMouseMotionListener(slistener);
    frame.removeKeyListener(slistener);

    LevelData data = lchooser.getLevelData(lvlNum);

    runLevel = new Level(this, frame, data, 0, 0, (Stack) data.getAbilityData().clone(), null);
    // this, frame, release, save %, start x, start y,
    // rrate, x offset, y offset, level time(milliseconds),
    // abilities, not multiplayer, ignore;

  }

  /**
   * display a miniture version of the map. display a miniture version of the map.
   *
   * @param lvl the level to display.
   */
  public void previewLevel(int lvl) {

    Graphics g = frame.getGraphics();

    try {
      BufferedImage miniMap =
          javax.imageio.ImageIO.read(
              getClass().getResource(lchooser.getLevelData(lvl).getFile() + ".png"));

      g.drawImage(miniMap, 250, 350, 400, 200, null);
    } catch (Exception e) {
      System.err.println("Error: level not found:" + lchooser.getLevelData(lvl).getFile() + ".png");
      System.err.println("Please Reload all game files.");
    }
  }

  /**
   * this function returns the level chooser. this function returns the level chooser.
   *
   * @return the level chooser.
   */
  public LevelChooser getlChooser() {
    return lchooser;
  }

  /**
   * This function returns the window to make the level in. This function returns the window to make
   * the level in.
   *
   * @return the window.
   */
  public Frame getFrame() {
    return frame;
  }

  /**
   * The number of the next level. The number of the next level.
   *
   * @return The number of the next level.
   */
  public int getNextLevel() {
    return nextLevel;
  }

  /**
   * The port to connect with. The port to connect with.
   *
   * @return The port to connect with.
   */
  public int getPort() {
    return port;
  }

  /**
   * this function sets the port number. this function sets the port number.
   *
   * @param in the new port number.
   */
  public void setPort(int in) {
    port = in;
    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(248, 135, 100, 20);
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("PORT : " + port, 250, 150);
    g.drawRect(248, 135, 100, 20);
  }

  /**
   * This functionr returns the host Name. This functionr returns the host Name.
   *
   * @return the Host Name.
   */
  public String getHost() {
    return hostName;
  }

  /**
   * This function sets the host to connect to. This function sets the host to connect to.
   *
   * @param in the new host.
   */
  public void setHost(String in) {
    hostName = in;
    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(248, 185, 300, 20);
    g.setColor(Color.GREEN);
    g.setFont(new Font(null, Font.PLAIN, 14));
    g.drawString("HOST: " + hostName, 250, 200);
    g.drawRect(248, 185, 300, 20);
  }

  /** start multiplayer for the client. start multiplayer for the client. */
  public void startMultiPlayerClient() {
    NetClient pclient = new NetClient(2, hostName, port);
    // startmulitgame;
    try {
      pclient.start();
    } catch (IOException e) {
      System.out.println("ERROR CONNECTING TO SERVER");
    }
    LevelData data = lchooser.getLevelData(nextLevel);
    frame.removeMouseListener(slistener);
    frame.removeMouseMotionListener(slistener);
    frame.removeKeyListener(slistener);
    runLevel = new Level(this, frame, data, 0, 0, (Stack) data.getAbilityData().clone(), pclient);
  }

  /** start multiplayer for the server. start multiplayer for the server. */
  public void startMultiPlayerServer() {
    NetServer pcserve = new NetServer(port);
    NetClient servclient = new NetClient(1, "127.0.0.1", port);
    try {
      pcserve.start();
      servclient.start(pcserve);
    } catch (IOException e) {
      System.err.println("Error starting Server");
      System.exit(0);
    }
    // startmultigame.
    LevelData data = lchooser.getLevelData(nextLevel);
    frame.removeMouseListener(slistener);
    frame.removeMouseMotionListener(slistener);
    frame.removeKeyListener(slistener);
    runLevel =
        new Level(this, frame, data, 0, 0, (Stack) data.getAbilityData().clone(), servclient);
  }

  /**
   * after the level, display the stats for a multiplayer game. after the level, display the stats
   * for a multiplayer game.
   */
  public void multiLevelFinished() {
    frame.addMouseListener(slistener);
    frame.addMouseMotionListener(slistener);
    frame.addKeyListener(slistener);

    Graphics g = frame.getGraphics();
    g.setColor(Color.BLUE);
    g.fillRect(0, 0, frame.getWidth(), frame.getHeight());
    g.setColor(Color.GREEN);
    // show stats, check to see if proceed to next level.
    int rescued = runLevel.getSaved();
    int needed = lchooser.getLevelData(nextLevel).getGoal();
    int maxLem = lchooser.getLevelData(nextLevel).getCount();

    g.drawString("% Lemmings Saved: " + rescued * 100 / maxLem, 300, 400);

    g.setFont(new Font(null, Font.BOLD, 24));
    if (rescued >= needed) {
      g.drawString("CONGRATULATIONS!!!", 200, 100);
      g.drawString("LEVEL " + ++nextLevel + " BEATEN", 200, 200);
    } else {
      g.drawString("LEVEL FAILED", 200, 100);
    }
    g.setFont(new Font(null, Font.PLAIN, 12));
  }

  /**
   * The Main function. This function starts it all up.
   *
   * @param args any arguments to the class.
   */
  public static void main(String[] args) {

    new LemmingCanvas();
  }
}
