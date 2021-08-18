

/**
 * tries to load a perf timer, and if that fails, just uses 
 * system.currentTimeMillis
 */
public class HiResTimer {


/** yay*/
   private static HiResTimer instance;
   /** yay*/
//   private PerfTimer perfTimer = null;
   /** this isn;t my code*/
 //  private boolean hiRes = true;
   

/* yay not my code*/
 //  private HiResTimer() {
   // try {
     //   perfTimer = new PerfTimer();
   // } catch (Exception e) {
        /**REPLACE WITH YOUR LOG/PRINTOUT*/
        //Log.getInstance().printDebug(
            //"Unable to load high res timer, resorting"
        //                        + 
        //" to System.currentTimeMillis()");
     //   hiRes = false;
   // } catch (Error e) {
        /**REPLACE WITH YOUR LOG/PRINTOUT*/
        //Log.getInstance().printDebug("Unable
        // to load high res timer, resorting"
        //                        + " to System.currentTimeMillis()");
       // hiRes = false;
   // } 
    
 //  } //end constrcutor

/**
 *
 * @return long something
 */
   public long currentTimeMillis() {
   // if (hiRes) {
     //   return perfTimer.currentTimeMillis();
    //} else {
        return System.currentTimeMillis();
    //}
   } //end currentTimeMillis


/**
 *
 * @return static something
 *
 * yay not my code
 *
 */

   public static HiResTimer getInstance() {

    if (instance == null) {
        instance = new HiResTimer();
    }

    return instance;
   } //end get instance

}
