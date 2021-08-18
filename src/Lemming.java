



import java.awt.image.BufferedImage; 
import java.awt.Color; 
import java.awt.Graphics2D; 


/**   the lemming class */

public class Lemming {



  /** mask of the level */
  private BufferedImage mask; 
  /** level image*/
  private BufferedImage level;  
  /**  current image  */
  private BufferedImage curImage; 
    /**  speed  */
  private boolean speed = false; 
  /**   speedup */
  private int speedUp = 0; 
    /**  frame of animation for lemming  */
  private   static BufferedImage rightMid; 
  /**  frame of animation for lemming    */
  private   static BufferedImage rightFront; 
  /**   frame of animation for lemming   */
  private   static BufferedImage rightBack; 
  /**    frame of animation for lemming  */
  private   static BufferedImage leftMid; 
  /**   frame of animation for lemming   */
  private   static BufferedImage leftFront; 
  /**  frame of animation for lemming    */
  private   static BufferedImage leftBack; 
  
  /**  frame of animation for lemming    */
  private   static BufferedImage rightMidClimb; 
  /**   frame of animation for lemming   */
  private   static BufferedImage rightFrontClimb; 
  /**    frame of animation for lemming  */
  private   static BufferedImage rightBackClimb; 
  /**    frame of animation for lemming  */
  private   static BufferedImage leftMidClimb; 
  /**    frame of animation for lemming  */
  private   static BufferedImage leftFrontClimb; 
  /**   frame of animation for lemming   */
  private   static BufferedImage leftBackClimb; 
/**   frame of animation for lemming   */
  private   static BufferedImage die1; 
  /**  frame of animation for lemming    */
  private   static BufferedImage die2; 
  /**  frame of animation for lemming    */
  private   static BufferedImage die3; 


/**    frame of animation for lemming  */
  private   static BufferedImage digImgL; 
  /**   frame of animation for lemming   */
  private   static BufferedImage digImgR; 

/**    frame of animation for lemming  */
  private   static BufferedImage blockerImg; 
  /**  frame of animation for lemming    */
  private   static BufferedImage fallingImgR; 
  /**  frame of animation for lemming    */
  private   static BufferedImage fallingImgL; 
/**   frame of animation for lemming   */
  private   static BufferedImage floatImg; 


/*  this is a currently executing action for a lemming  */
  //  private boolean bashing = false; 
    /**    this is a currently executing action for a lemming*/
    private boolean exploding = false; 
    /*  this is a currently executing action for a lemming  */
   // private boolean floating = false; 
    /** this is a currently executing action for a lemming   */
    private boolean digging = false; 
    /**  this is a currently executing action for a lemming  */
    private boolean blocking = false; 
    /**   this is a currently executing action for a lemming */
    private boolean mining = false; 
    /**  this is a currently executing action for a lemming  */
    private boolean climbing = false; 
    /**   this is a currently executing action for a lemming */
    private boolean falling = false; 
 /** this is an attribute of the lemming,  
  not necesarily curently being executed   */
    private boolean digger = false; 
    /** this is an attribute of the lemming,  
  not necesarily curently being executed   */
    private boolean blocker = false; 
    /**  this is an attribute of the lemming,  
  not necesarily curently being executed  */
    private boolean exploder = false; 
    /**   this is an attribute of the lemming,  
  not necesarily curently being executed */
    private boolean floater = false; 
    /**  this is an attribute of the lemming,  
  not necesarily curently being executed  */
    private boolean basher = false; 
    /** this is an attribute of the lemming,  
  not necesarily curently being executed   */
    private boolean miner = false; 
    /**  this is an attribute of the lemming,  
  not necesarily curently being executed  */
    private boolean climber = false; 
    /**   this is an attribute of the lemming,  
  not necesarily curently being executed */
    private boolean bridger = false; 

/** time that the lemming is first told to explode*/

    private long explodeStart = 0;
    
    
    /** pause variable for pause at the end of building a bridge*/
    private boolean bridgePause = false;

    /**   the lemming has exited the level */
    private boolean lemmingExited = false; 
/**  death frame 1  */
    private boolean die1Bool = false; 
    /**  death frame  2 */
    private boolean die2Bool = false; 
    /**  death frame 3  */
    private boolean die3Bool =  false; 
    
    /** dead   */
    private boolean dead = false; 
    /**  dying  */
    private boolean dying = false; 
    /**  death by falling */
    private boolean fallDie = false; 
    /**  death by explosion  */
    private boolean expDie = false; 
    /* death by bad ground (lava / water)   */
    //private boolean orangeDie = false; 

/**  counter for digger  */
    private int digCounter = 0; 
    /** counter for falling   */
    private int fallCounter = 0; 
    /**  counter for climbing  */
    private int  climbCounter = 0; 

    /** the pause Counter*/    
    private int pauseCounter = 0;

   /*  direction the lemming is walking prior to climbing  */
    //private boolean climbDirRightWall = true;  

    
    /**  x position of lemming  */
    private int xPos; 
    /**   y position of lemming */
    private int yPos; 
    
    /*  previous x position   */
   // private int oldX; 

/** time counter   */
    private long time = 0; 
    
    /** kernel (need to fix)   */
    private static LiteKernel  kernel; //= new LiteKernel(); 
   /**   if true then lemming is moving to the right */
    private boolean rightDir = true;  
    
    
    /** if true, then the lemming is still*/
    private boolean noDir = false;
    

/** dummy constructor    */
    public Lemming () {
        this.xPos = 0; 
        this.yPos = 0; 
    }


/**  lemming constructor
 *
 *   @param xPos x
 *   @param yPos dfg
 *   @param mask mask 
 *   @param levelImg level
 *   
 *
 *
 *  */
    public Lemming (int xPos,  int yPos, 
    BufferedImage mask,  BufferedImage levelImg) {
         this.mask = mask; 
         this.level = levelImg;  
         this.xPos =  xPos; 
         this.yPos =  yPos; 
        
               
             
         this.curImage = rightMid; 
     
     }


/** init the lemming stuff 

   

  */
   public void init() {


        try { 
         
            rightMid = javax.imageio.ImageIO.read
            (getClass().getResource("rightMid.png")); 
            rightFront = javax.imageio.ImageIO.read
            (getClass().getResource("rightFront.png")); 
            rightBack = javax.imageio.ImageIO.read
            (getClass().getResource("rightBack.png")); 
            leftMid = javax.imageio.ImageIO.read
            (getClass().getResource("leftMid.png")); 
            leftFront = javax.imageio.ImageIO.read
            (getClass().getResource("leftFront.png")); 
            leftBack = javax.imageio.ImageIO.read
            (getClass().getResource("leftBack.png")); 

            rightMidClimb = javax.imageio.ImageIO.read
            (getClass().getResource("rightMidClimb.png")); 
            rightFrontClimb = javax.imageio.ImageIO.read
            (getClass().getResource("rightFrontClimb.png")); 
            rightBackClimb = javax.imageio.ImageIO.read
            (getClass().getResource("rightBackClimb.png")); 
            leftMidClimb = javax.imageio.ImageIO.read
            (getClass().getResource("leftMidClimb.png")); 
            leftFrontClimb = javax.imageio.ImageIO.read
            (getClass().getResource("leftFrontClimb.png")); 
            leftBackClimb = javax.imageio.ImageIO.read
            (getClass().getResource("leftBackClimb.png")); 

        


            digImgL = javax.imageio.ImageIO.read
            (getClass().getResource("digLeft.png")); 
            digImgR = javax.imageio.ImageIO.read
            (getClass().getResource("digRight.png")); 
            blockerImg = javax.imageio.ImageIO.read
            (getClass().getResource("blocker.png")); 
            fallingImgR =  javax.imageio.ImageIO.read
            (getClass().getResource("fallingDownRight.png")); 
            fallingImgL =  javax.imageio.ImageIO.read
            (getClass().getResource("fallingDownLeft.png")); 

            floatImg = javax.imageio.ImageIO.read
            (getClass().getResource("floater.png")); 

            die1 = javax.imageio.ImageIO.read
            (getClass().getResource("die1.png")); 
            die2 = javax.imageio.ImageIO.read
            (getClass().getResource("die2.png")); 
            die3 = javax.imageio.ImageIO.read
            (getClass().getResource("dead.png")); 


             kernel = new LiteKernel();     

                      
            
               
        } catch (Exception e)         {
            System.out.println("error reading buffered images"); 
        } 




   }
   
   /** mig right color  
   
    
    @return color
   
   
     */
    
   public int getRightUpColor() {  
    
        int xOffset = curImage.getWidth(); 
        int yOffset = curImage.getHeight() / 2; 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset); 
    }
    
    
    
    /**   mid left color 
    
    @return color
    
    */
    
    
    public int getLeftUpColor() { 
    
        int xOffset = 0; 
        int yOffset = curImage.getHeight() / 2; 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset); 
    }

    
  /**  low right color
   *
   *    @return color  
   */

    public int getRightColor() {  
    
        int xOffset = curImage.getWidth() - 2; 
        int yOffset = curImage.getHeight(); 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset - 2); 
    }
    
    /**  low left color 
    
        @return left low color
    
     */
    public int getLeftColor() { 
    
        int xOffset = 2; 
        int yOffset = curImage.getHeight(); 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset - 2); 
    }
    
    /**  bottom center color
     *
     *  @param offset offset from the bottom of lemming
     *   @return  return the color
     *
     *
     *  */
    public int getBottomColor(int offset) {  
    
        int xOffset = curImage.getWidth() / 2; 
        int yOffset = curImage.getHeight(); 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset + offset); 
    
    }
   
     /**  top center color 
     
     @return color (top)
     
     
      */
    public int getTopColor() {  
    
        int xOffset = curImage.getWidth() / 2; 
        
    
        return mask.getRGB(xPos + xOffset ,  yPos); 
   
    }

/**  center color 


    @return the returned color

 */
    public int getColor() {  
    
        int xOffset = curImage.getWidth() / 2; 
        int yOffset = curImage.getHeight() / 2; 
    
        return mask.getRGB(xPos + xOffset,  yPos + yOffset); 
    
    }
    

 
    /**  gets x position
     *
     *@return x positiion
     *
     * */
    public int getXPos() {
        return this.xPos; 
    }
    
    /**  sets x position  
    
    @param xPos ad
    
    */
    public void setXPos(int xPos) {
        this.xPos = xPos; 
    }
    
    
    /**  gets y position
     *
     *@return y position
     *
     *  */
    public int getYPos() {
        return this.yPos; 
    }
    
    /**  sets y position 
    
    @param yPos ad
    
    
     */
    
    public void setYPos(int yPos) {
        this.yPos = yPos; 
    }
    
    
    /**  set the current image  
    
        @param newImage zdzdc
    
    */
    public void setCurImage(BufferedImage newImage) {
        
        this.curImage = newImage; 
        
    }
    
    /**  get the current image 
    
        @return the current lemming image
    
     */
    public BufferedImage getCurImage() {
        
        return this.curImage; 
        
    }

/**  move (calls the kernel move  */
    public void move() {
        
        
        
        kernel.move(this); 
        
        
        //rightDir = kernel.getRightDir(); 
        
    }
    
    
    /**  update the image  */
    public void updateImage() {
     
        long timer;  
      
    
        this.time++;  
        
        timer = this.time % 3;  

       //System.out.println("Update " + time); 
        
       // rightDir = kernel.getRightDir(); 


       if (dead) {
         return; 
    }

       
        if (falling && !(digger) && !exploding) {


           if (floater) {

                fallCounter = 0; 

                 curImage = floatImg; 

          } else {

           if (0 == timer) {
             curImage = fallingImgR; 
            } if (1 == timer) {
                 curImage = fallingImgL; 
           } if (2 == timer && (0 == (fallCounter % 2))) {
            
            curImage = fallingImgR; 
           } if (2 == timer && (0 != (fallCounter % 2))) {
            
             curImage = fallingImgL; 
    
            }

           fallCounter++; 


          }

           setFalling(false); 


        } else if (isDigger() && digging && !exploding) {


           if (0 == timer) { 
           curImage = digImgR; 
           } if (1 == timer) {
              curImage = digImgL; 
           } if (2 == timer && (0 == (digCounter % 2))) {
            curImage = digImgR; 
           } if (2 == timer && (0 != (digCounter % 2))) {
             curImage = digImgL; 
        
           }
           digCounter++; 
           digging(false); 
        } else if  (dying) {
                
                 if (timer == 0) {
                 curImage = die1; 

                 die1Bool = true; 
           } if (timer == 1  && die1Bool) {

                 curImage = die2; 

                die2Bool = true; 
           

        } if (timer == 2 && die2Bool) {


                 curImage = die3; 
            
                die3Bool = true;         
                   
           } if (die3Bool) {
                         dead = true; 
        }
        } else if (isExploder() && expDie) {
        
      
           
        
           if (timer == 0) {
                 curImage = die1; 

                 die1Bool = true; 
           } if (timer == 1  && die1Bool) {

                 curImage = die2; 

                die2Bool = true; 
           }  if (timer == 2 && die2Bool) {


                 curImage = die3; 
            
                 die3Bool = true;     
           }   if (die3Bool) {


                         dead = true; 

                         

        
                
                        Graphics2D g2mask = mask.createGraphics(); 

                        Graphics2D g2level = level.createGraphics(); 


                        //Color levColor = g2level.getColor(); 

                        g2level.setColor(new Color(level.getRGB(200,  200))); 
                        g2mask.setColor(Color.black); 


                        g2level.fillOval(xPos - 2,  yPos - 2,  60,  60); 

                        g2mask.fillOval(xPos - 2,  yPos - 2,  60,  60); 

                        //g2level.setColor(levColor); 

                        //g2level.fillOval(xPos - 2,  yPos - 2,  75,  75); 
          
          }  



        } else if (isBlocker() && blocking) {

               curImage = blockerImg; 


        } else if (isClimber() && climbing) {
        
        if (0 == timer && rightDir) { 
            curImage = rightMidClimb; 
        } if (1 == timer && rightDir)  { 
            curImage = rightFrontClimb; 
        } if (2 == timer && rightDir)  { 
        
            curImage = rightBackClimb; 
               
        } if (0 == timer && !rightDir)  {
            
                curImage = leftMidClimb; 
        
        } if (1 == timer && !rightDir) {
            
                curImage = leftFrontClimb; 
        } if (2 == timer && !rightDir) {
        
        
         curImage = leftBackClimb; 
         
       }

     } else {
        
      ///  fallCounter = 0; 

        
        if (0 == timer && rightDir) {
            curImage = rightMid; 
        } if (1 == timer && rightDir) {
             curImage = rightFront; 
        } if (2 == timer && rightDir) {
             curImage = rightBack; 
               
        } if (0 == timer && !rightDir) {
        
         curImage = leftMid; 
        } if (1 == timer && !rightDir) {
             curImage = leftFront; 
        } if (2 == timer && !rightDir) {
             curImage = leftBack; 
             }

     }
    }


/**  set the falling on off 


@param falling adas


 */

    public void setFalling(boolean falling) {

        this.falling = falling; 

    }
        
        
        /** is it falling?
         *
         *  @return falling
         *
         *   */
    public boolean isFalling() {


        return falling; 

    }    

/**  is it a digger?  

    @return digger

*/
    public boolean isDigger() {
        return digger; 
    }


/**  is it digging? 

    @return digging

 */
    public boolean isDigging() {
        return digging; 
    }


/** toggle digging 

    @param onoff diging
    
  */
    public void digging(boolean onoff) {

         digging = onoff; 

    }

/**  toggle digger
 *
 *    @param dig skjfd
 *
 *  */
    public void setDigger(boolean dig) {
        digger = dig; 
    }


/**   dig action */
    public void dig() {


      int digColor; 
        int levelColor; 
           
//        int xOffset = curImage.getWidth() / 2; 
        int yOffset = (curImage.getHeight()) / 2; 
    
       digColor = (Color.black).getRGB(); 
        levelColor = level.getRGB(200,  200); 
        

        
 
         if (getBottomColor(0) == (Color.red).getRGB()) {



                digging = true;  

                

                for (int j = 0;  j < curImage.getWidth();  j++) {


                if  (getLeftColor() != (Color.red).getRGB()
                || getRightColor() != (Color.red).getRGB()) {


                 level.setRGB(xPos + j,  yPos
                 + (2 * yOffset) ,  levelColor);  
                      
                       
                          level.setRGB(xPos + j,  yPos
                          + (2 * yOffset) + 1 ,  levelColor);  

                         level.setRGB(xPos + j,  yPos
                         + (2 * yOffset) + 2 ,  levelColor);  

                      
                        mask.setRGB(xPos + j,  yPos
                        + (2 * yOffset) ,  digColor); 
                                   
                        mask.setRGB(xPos + j,  yPos
                        + (2 * yOffset) + 1,  digColor); 


                       mask.setRGB(xPos + j,  yPos
                       + (2 * yOffset) + 2,  digColor); 

 
                    } else {


                  level.setRGB(xPos + j,  yPos ,  levelColor);  

                         mask.setRGB(xPos + j,  yPos ,  digColor); 




                    }
                  
 
               }
      
        }

    }



/** is it a blocker?  

    @return blocker


 */
    public boolean isBlocker() {
        return blocker; 
    }
    
    
/** toggle blocker 

    @param block sdf+

  */
    public void setBlocker(boolean block) {
        blocker = block; 
    } 
    
    
/** is it blocking?  

    @return blocking


*/
    public boolean isBlocking() {

        return blocking; 
        
    }

/**   block action */
    public void block() {

        int xOffset = curImage.getWidth(); 
        int yOffset = curImage.getHeight(); 
    
       




           if ((Color.black).getRGB() !=  getBottomColor(0)) { 


                
                blocking = true; 


              for (int i = 0;  i < yOffset;  i++) {

                for (int j = 0;  j < xOffset;  j++) {

                        mask.setRGB(xPos + j, 
                        yPos + i ,  (Color.green).getRGB()); 
                                   
                        
                  
 
               }


           }

        }


             


        

    }




 /**  is it climbing
  *
  * @return climbers sfdf
  *
  *  */   
    public boolean isClimber() {
        return climber; 
    }
    
/** toggle climber 


    @param climb sesdf

  */
    public void setClimber(boolean climb) {
        climber = climb; 
    }
    
    
/** is it climbing 

@return climbing

  */
    public boolean isClimbing() {

        return climbing; 

    }
    
    
/** toggle climbing 

@param climbing sdfs

  */
   public void setClimbing(boolean climbing) {

        this.climbing = climbing; 

    }

/** climb action 

    @param rightDirLoc true means right
*/
    public void climb(boolean rightDirLoc) {

                
       
      //  int xOffset = curImage.getWidth(); 
      //  int yOffset = curImage.getHeight(); 
        

                
                

                if ((Color.black).getRGB() != getTopColor()) {
                
                               
                        



                        falling = true;                

                        climbing = false; 



                } else if  (!(climbable(rightDirLoc))) {
                
                        if (rightDirLoc) {

                        setXPos(getXPos() + curImage.getWidth() + 8); 
                        setYPos(getYPos() 
                        - (curImage.getWidth() - curImage.getHeight()) - 5); 

                        } else {

                        setXPos(getXPos() - curImage.getWidth() - 8); 
                        setYPos(getYPos() 
                        - (curImage.getWidth() - curImage.getHeight()) - 5); 


                        }

                
                        climbing = false;  /// add protection ??

                      



                } else if (climbable(rightDirLoc)) {
        
                      
                       climbing = true; 


                        yPos -= 2; 




                }
        


                /// else climbing==false


    }



/** is it climbable?   

@return clibmable wall
@param rightDirLoc or left
    

*/
    public boolean climbable(boolean rightDirLoc) {


          int wallColor; 
        
          boolean retVal; 


         if (rightDirLoc) {

          wallColor = getRightUpColor(); 
      
          
  
        } else {

           wallColor = getLeftUpColor(); 



        }

        retVal = (Color.red).getRGB() == wallColor; 



        return retVal; 


    }
    
    
/** is it bashable?   

@return bashable wall
@param rightDirLoc or left
@param   bashLen ftw  

*/
    public boolean bashable(boolean rightDirLoc, int bashLen) {


          int wallColor; 
        
          boolean retVal; 


         if (rightDirLoc) {

          wallColor = mask.getRGB(xPos +  curImage.getWidth() 
          + bashLen,  yPos +  curImage.getHeight() - 4);
          
  
        } else {
           
           wallColor = 
           mask.getRGB(xPos - bashLen,  yPos + curImage.getHeight()  - 4);



        }

        retVal = (Color.red).getRGB() == wallColor; 



        return retVal; 


    }

    
    




/**  is it an exploder? 


@return exploder

 */
    public boolean isExploder() {
        return exploder; 
    }

/**  toggle  exploding
 *
 *   @param expl asdas
 *
 *  */
    public void setExploder(boolean expl) {
        exploder = expl; 

    }

/**  explode action */
     public void explode() {

               
       exploding = true; 
        
              

    }

/** is it a floater  

    @return floater
    
 */
      public boolean isFloater() {
        return floater; 
    }


/** figler    


     @param floate dfdf

 */
    public void setFloater(boolean floate) {
        floater = floate; 
    }

   
/**   stooood  */
    public void floatt() {


        curImage = floatImg; 

   }

/**  is it a basher?
 *
 *  @return basher 
 * 
 
  */
    public boolean isBasher() {
        return basher; 
    }


/**  toggler basher 


    @param bash asdadG

 */
    public void setBasher(boolean bash) {
        basher = bash; 
    }


/**  bash action
 *
 *   @param rightDirLoc true if  right else left
 *
 *  */
    public void bash(boolean rightDirLoc) {

        int xOffset = curImage.getWidth(); 
        int yOffset = curImage.getHeight(); 


       int levelColor = level.getRGB(200,  200); 



        int backSet; 

        backSet =  (-1) * (xOffset / 2); 


       if (climbable(rightDirLoc) || bashable(rightDirLoc, 7)) { 

          if (rightDirLoc) {

      
                for (int i = backSet;  i <= (xOffset / 4);  i++) {


                        for (int j = 0;  j < yOffset;  j++) {

            level.setRGB(xPos + xOffset  + i ,  yPos + j ,  levelColor);  

                      
                          mask.setRGB(xPos +  xOffset
                          + i ,  yPos + j ,  (Color.black).getRGB());  


                        }

                }
                
          
          
  
        } else {

                 for (int i = backSet;  i <= (xOffset / 4);  i++) {


                        for (int j = 0;  j < yOffset;  j++) {

                               level.setRGB(xPos
                               - i ,  yPos + j ,  levelColor);  

              
                      
                          mask.setRGB(xPos
                          - i ,  yPos + j , (Color.black).getRGB());  


                        }

                }
                
                
         




        }



        } else {
            
            
               
               
               setBasher(false); 

       }

    }


/**  is it a miner? 

@return  miner
 */
    public boolean isMiner() {
        return miner; 
    }


/**   toggle miner
 *
 *@param mine adad
 * */
    public void setMiner(boolean mine) {
        miner = mine; 
    }

/**  mine action  */

    public void mine() {

       

          int mineLocColor; 
        int levelLocColor; 

           
        int xOffset = curImage.getWidth() / 2; 
        int yOffset = (curImage.getHeight()) / 2; 
    
       mineLocColor = (Color.black).getRGB(); 
        levelLocColor = level.getRGB(200,  200); 
        

        Graphics2D g2LocLevel; 
        
        Graphics2D g2LocMask; 
 


  if (getBottomColor(0) == (Color.red).getRGB()) {

        


                mining = true;  

                
                g2LocLevel = level.createGraphics(); 

                g2LocMask = mask.createGraphics(); 

                g2LocLevel.setColor(new Color(levelLocColor)); 
                

                g2LocMask.setColor(Color.black); 
                

              if (rightDir) {

               // for (j = 0;   j < curImage.getWidth() / 4;  j++) {

                           g2LocLevel.fillRect(xPos
                            - xOffset + 10 ,  yPos - 5 ,  20,  yOffset * 2); 
                            g2LocMask.fillRect(xPos
                             - xOffset + 10 ,  yPos - 5,  20,  yOffset * 2); 

                            xPos += 4; /// originally 2
                            yPos++;
                                
               //}
               
               



             } else {


                        //for (j = 0;  j < curImage.getWidth() / 4;  j++) {

                           g2LocLevel.fillRect(xPos +  xOffset - 10 , 
                           yPos  - 5,  20,  yOffset * 2); 
                           g2LocMask.fillRect(xPos +  xOffset - 10,  yPos - 5
                           ,  20,  yOffset * 2); 

                           
                           xPos -= 4; ///originally 2
                            yPos++;
                           
                                
                      //   }






                }

        } else {
        
        
            miner = false;
        
        }


   }


/**  is it a bridge 

    @return bridger sdfsf

 */

    public boolean isBridger() {
        return bridger; 
    }
    
    
    
    /**  toggler bridger
     *
     *  @param bridge as
     *
     *  */
    public void setBridger(boolean bridge) {
        bridger = bridge; 
    }



/**  bridging action  */

    public void bridge() {

       

        int xOffsetLoc = curImage.getWidth(); 
        int yOffsetLoc = curImage.getHeight(); 


        
       
       Graphics2D g2LocLevel = level.createGraphics(); 
        ////take this out and make a static
       Graphics2D g2LocMask = mask.createGraphics();  
       ////take this out and make a static

       g2LocLevel.setColor(Color.orange);   
       g2LocMask.setColor(Color.red);   

        

        if (!(climbable(rightDir)) && (Color.black).getRGB() == getTopColor()) {
   

       if (climbCounter < 32) {

          if (rightDir) {



                           
      
          
     
                        g2LocLevel.fillRect(xPos 
                        + xOffsetLoc / 2,  yPos 
                        + yOffsetLoc - 4,  xOffsetLoc / 2,  12); 



                       g2LocMask.fillRect(xPos + xOffsetLoc / 2 ,  yPos
                       + yOffsetLoc - 4,  xOffsetLoc / 2,  12); 
          
  
        } else {


                       g2LocLevel.fillRect(xPos  ,  yPos 
                       + yOffsetLoc - 4,  xOffsetLoc / 2,  12); 




                       g2LocMask.fillRect(xPos  ,  yPos 
                       + yOffsetLoc - 4,  xOffsetLoc / 2,  12); 



        }



       

        

        


        climbCounter++; 



        }  else if (climbCounter < 36) {


                climbCounter = 0; 

                
                
                
                bridgePause = true;
                
                
                
              
                
                
             setBridger(false); 


     }
     
     
    }
     
  } 
    

/**   set it to dead */

        public void setDead() {

                dead = true; 

        }

/** is it dead?
 *
 *@return dead
 *
 *
 *   */

        public boolean getDead() { 

                return dead; 


        }



/**  has it exited the level 
    
      @return lemming has exited

    
 */
        public boolean exited() {


                lemmingExited =  ((Color.blue).getRGB() == getLeftUpColor()
                || (Color.blue).getRGB() == getRightUpColor()); 
        
                return lemmingExited; 
        }


/**   get the counter for falling 



    @return counter for falling motion

  */

        public int getFallCounter() {


                return fallCounter; 

        }


    /** rreset the falling counter (for safe landings and parachute)   */    
        public void resetFallCounter() {


                fallCounter = 0; 

        }


/** set the lemming to die by falling 


    @param die asd
  */

        public void setFallDying(boolean die) {

                fallDie = true; 

        }

/**  is it falling death? 

    @return is it dying from falling?


 */
         public boolean getFallDying() {

                return fallDie; 

        }

/**   set the lemming to die 

    @param die dfd

*/
       public void setDying(boolean die) {

                dying = die; 

        }

/** is it dying?
 *
 *
 *@return dying?
 *
 *  */
         public boolean getDying() {

                return dying; 

        }

/**  the ammount the lemming has to fall inoder to die 

    @return the interger length of fall for death
    
 */
        public int dropLen() {

                return level.getHeight() / 4; 


        }

/**  get the level width
 *
 *  @return the width of the level
 *
 * */
        public int getCanvasX() {

                return level.getWidth(); 

        }
/**  get the level height 
    
        @return the height of the level


*/
        public int getCanvasY() {

                return level.getHeight(); 

        }

/**   getht e ammoutn of speedup
 *
 *   @return speedup magnitude
 *
 * */
        public int getSpeedUp() {

                return speedUp; 

        }

/**  toggler speedup  */

        public void toggleSpeed() {

                speed = !speed; 


                if (speed) {

                        
                     speedUp += 8;         


                } else {

                
                  speedUp -= 8; 



                }

        }

 /** 

@return rightDir

*/

  public boolean getRightDir() {
        return this.rightDir;
    }
    
    /** 

    @param rightDir sdfd

    */

  public void setRightDir(boolean rightDir) {
        this.rightDir = rightDir;
    }
    
    
    
    
    
    
       /** 

        @return noDir

        */

  public boolean getNoDir() {
        return this.noDir;
    }  

    
    
       /** 

        @param noDir ads

        */

  public void setNoDir(boolean noDir) {
        this.noDir = noDir;
    }  
    
    
    /**
    
    
    @return boolean telling if exploding 
            death is enabled
    
    */
    
    public boolean explodeDie() {
    
        
        return expDie;
        
        
    }

    
    
    /**

        die    
    
    @param expDiee die
    
    */
    
    public void  setExplodeDie(boolean expDiee) {
    
        
        this.expDie = expDiee;
        
        
    }
    
    /** 
       yay, setExpTime
    
        @param timeee set the time, used for the init exploder 
    
    
    */
    
    public void setExpTime(long timeee) {
    
    
        this.explodeStart = timeee;
    
    }
    
    
    /**
    
        return the init time
    
        @return long returns the time
    
    
    */
    
    public long getExpTime() {
    
    
        return   explodeStart;
    
    
    }
    
    
    
    /**
    
        sets the lemming to pause and wait for
        input.
    
        @param pause the pausing variable
    
    
    
    */
    
    
    public void setBridgePause(boolean pause) {
    
    
        this.bridgePause = pause;
    
    }
    
    
    /**
    
        return the init time
    
        @return boolean returns bridgePause
    
    
    */
    
    public boolean getBridgePause() {
    
    
        return   bridgePause;
    
    
    }
    
    
     /**
    
        pause counter
    
        @param counter pause count
    
    
    
    */
    
    
    public void setPauseCounter(int counter) {
    
    
        this.pauseCounter = counter;
    
    }
    
    
    /**
    
        return int the pauseing counter
    
        @return boolean returns bridgePause
    
    
    */
    
    public int getPauseCounter() {
    
    
        return   pauseCounter;
    
    
    }
    
    
    
    
    
 
    
    
}


