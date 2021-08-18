import java.awt.Point;
import java.util.Stack;

/** This class stores data on the levels. This class stores data on the levels. */
public class LevelData {

  /** The name of the level. */
  private String fileName;

  /** The number of lemmings to release. */
  private int lemmingCount;

  /** the release rate. */
  private int releaseRate;

  /** The goal for saved lemmings. */
  private int lemmingGoal;

  /** the time for the level */
  private int gameTime;

  /** The starting position. */
  private Point startPos;

  /** the uses for each ability. */
  private Stack abilityData;

  /**
   * This constructor calls the other to make a basic level. This constructor calls the other to
   * make a basic level.
   */
  public LevelData() {
    this("", 0, 0, 0, 5, new Point(0, 0), new Stack());
  }

  /**
   * The Constructor sets up the variables. The Constructor sets up the variables.
   *
   * @param name the name of the level.
   * @param count the number of lemmings to release.
   * @param rate the release rate.
   * @param goal the number of lemmings to save.
   * @param time the time for the level.
   * @param start the starting point.
   * @param abilities information on the abilities.
   */
  public LevelData(
      String name, int count, int rate, int goal, int time, Point start, Stack abilities) {
    fileName = name;
    lemmingCount = count;
    releaseRate = rate;
    lemmingGoal = goal;
    gameTime = time;
    startPos = start;
    abilityData = abilities;
  }

  /**
   * This function sets the File Name This function sets the File name
   *
   * @param name The new Name.
   */
  public void setFile(String name) {
    fileName = name;
  }

  /**
   * This function sets the Count This function sets the Count
   *
   * @param count The new Count.
   */
  public void setCount(int count) {
    lemmingCount = count;
  }

  /**
   * This function sets the rate This function sets the rate
   *
   * @param rate The new Rate.
   */
  public void setRate(int rate) {
    releaseRate = rate;
  }

  /**
   * This function sets the Goal This function sets the Goal
   *
   * @param goal The new Goal.
   */
  public void setGoal(int goal) {
    lemmingGoal = goal;
  }

  /**
   * This function sets the Time This function sets the Time
   *
   * @param time The new Time.
   */
  public void setTime(int time) {
    gameTime = time;
  }

  /**
   * This function sets the Start Point This function sets the Start Point
   *
   * @param start The new Start Point.
   */
  public void setStart(Point start) {
    startPos = start;
  }

  /**
   * This function gets the File Name This function gets the File Name
   *
   * @return The File name.
   */
  public String getFile() {
    return fileName;
  }

  /**
   * This function gets the Count This function gets the Count
   *
   * @return The Count.
   */
  public int getCount() {
    return lemmingCount;
  }

  /**
   * This function gets the Release Rate This function gets the Release Rate
   *
   * @return The Release Rate.
   */
  public int getRate() {
    return releaseRate;
  }

  /**
   * This function gets the Goal This function gets the Goal
   *
   * @return The Goal.
   */
  public int getGoal() {
    return lemmingGoal;
  }

  /**
   * This function gets the Time This function gets the Time
   *
   * @return The Time.
   */
  public int getTime() {
    return gameTime;
  }

  /**
   * This function gets the Start Position This function gets the Start Position
   *
   * @return The Start position.
   */
  public Point getStart() {
    return startPos;
  }

  /**
   * This function gets the Ability info This function gets the Ability Info
   *
   * @return The Ability Info.
   */
  public Stack getAbilityData() {
    return abilityData;
  }
}
