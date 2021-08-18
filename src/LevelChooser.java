import java.awt.Point;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Stack;

/**
 * get level statistics. This class reads from the file levelChooser.txt and uses the info therein
 * to get data on each of the levels, in order.
 *
 * <p>(instructions on the format of the file can be found in the sample)
 */
public class LevelChooser {

  /** The List of levels */
  private Stack levels;

  /**
   * This function reads in and interprets the data. This function reads in and interprets the data
   * from the file.
   */
  public LevelChooser() {
    levels = new Stack();
    File levelText;
    FileReader in;
    BufferedReader readFrom = null;
    try {
      levelText = new File("levelChooser.txt");
      in = new FileReader(levelText);
      readFrom = new BufferedReader(in);
      int c;
      while (-1 != (c = readFrom.read())) {
        String levelName = "";
        int lems = 0;
        int rate = 0;
        int goal = 0;
        int time = 0;
        int x = 0;
        int y = 0;
        Point start;
        if ('#' == c) {
          readFrom.readLine();
          continue;
        }
        c = (char) readFrom.read();
        if ('|' != c) {
          c = (char) readFrom.read(); // second | after level number
        } // add another if we support 100+ levels
        /*file name*/ c = (char) readFrom.read(); // second |
        while ('|' != (char) (c = (char) readFrom.read())) {
          levelName = levelName.concat(Character.toString((char) c));
        }
        /*num released*/ c = (char) readFrom.read(); // second |
        lems = Character.getNumericValue((char) (readFrom.read()));
        lems *= 10;
        lems += Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if ('|' != (char) c) {
          lems *= 10;
          lems += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
        }
        /*release rate*/ c = (char) readFrom.read(); // second |
        rate = Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if ('|' != (char) c) {
          rate *= 10;
          rate += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
        }
        /*goal number*/ c = (char) readFrom.read(); // second |
        goal = Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if ('|' != (char) c) {
          goal *= 10;
          goal += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
          if ('|' != (char) c) {
            goal *= 10;
            goal += Character.getNumericValue((char) c);
            c = (char) readFrom.read();
          }
        }
        /*time*/ c = (char) readFrom.read(); // second |
        time = Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if ('|' != (char) c) {
          time *= 10;
          time += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
        }
        /*x start*/ c = (char) readFrom.read(); // second |
        x = Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if (',' != (char) c) {
          x *= 10;
          x += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
          if (',' != (char) c) {
            x *= 10;
            x += Character.getNumericValue((char) c);
            c = (char) readFrom.read();
          }
        }
        /*y start*/ y = Character.getNumericValue((char) (readFrom.read()));
        c = (char) readFrom.read();
        if ('\n' != (char) c) {
          y *= 10;
          y += Character.getNumericValue((char) c);
          c = (char) readFrom.read();
          if ('\n' != (char) c) {
            y *= 10;
            y += Character.getNumericValue((char) c);
            c = (char) readFrom.read();
          }
        }
        /*abilities:*/ Stack abilities = new Stack();
        int temp;
        for (int lq = 0; lq < 7; lq++) {
          c = (char) readFrom.read();
          if ('-' == (char) c) {
            temp = -1;
            c = (char) readFrom.read();
            c = (char) readFrom.read();
          } else {
            temp = Character.getNumericValue((char) c);
            c = (char) readFrom.read();
            if ('|' != (char) c) {
              temp *= 10;
              temp += Character.getNumericValue((char) c);
              c = (char) readFrom.read();
            }
          }
          abilities.add(new Integer(temp));
          c = (char) readFrom.read(); // second |
        } // loop

        c = (char) readFrom.read();
        if ('-' == (char) c) {
          temp = -1;
          c = (char) readFrom.read();
          c = (char) readFrom.read();
        } else {
          temp = Character.getNumericValue((char) c);
          c = (char) readFrom.read();
          if ('\n' != (char) c) {
            temp *= 10;
            temp += Character.getNumericValue((char) c);
            c = (char) readFrom.read();
          }
        }
        abilities.add(new Integer(temp));
        Stack tempStack = new Stack();
        for (int i = 7; i >= 0; i--) {
          tempStack.push(abilities.elementAt(i));
        }
        start = new Point(x, y);
        levels.addElement(new LevelData(levelName, lems, rate, goal, time, start, tempStack));
      }
      readFrom.close();
    } catch (IOException e) {
      System.err.println("Error reading from file");
      System.err.println("Please replace levelChooser.txt");
      System.exit(-1);
    }
  }

  /**
   * This function gets the data for the selected level. This function gets the data for the
   * selected level.
   *
   * @param i the level to get data for.
   * @return the data for the selected level.
   */
  public LevelData getLevelData(int i) {
    return (LevelData) levels.elementAt(i);
  }

  /**
   * This function returns the number of levels available. This function returns the number of
   * levels available.
   *
   * @return number of levels available.
   */
  public int getLevelCount() {
    return levels.size();
  }
}
