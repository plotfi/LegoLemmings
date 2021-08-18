



import java.awt.Color;







/** the litekernel class*/

public class LiteKernel {
    

    
 

/* this needs to be gone! */
   // private boolean rightDir = true;


/* same here*/

  //  private boolean noDir = false;



/** 

@return rightDir

*/

 /*   public boolean getRightDir() {
        return this.rightDir;
    }*/


/**
 *
 * @param lemming sdfd
 *
 *
 */

    public void move(Lemming lemming) {
        int xPos = lemming.getXPos();
        int yPos = lemming.getYPos();

///wtf

        if (lemming.getDead() || lemming.isBlocking()) {
                ///lemming = null;
                
                return;
        } if (lemming.getFallCounter() > lemming.dropLen() / 5 
        && !lemming.isFloater()) {
       lemming.setFallDying(true);
        } if (lemming.getFallDying() && (Color.black).getRGB() 
        != lemming.getBottomColor(0) && !(lemming.isFloater())) {
        lemming.setDying(true);
       } if (lemming.exited()) {
                ///lemming = null;           
                return;
        } if (lemming.isDigger()) {
       lemming.dig();
        } if (lemming.getBridgePause()) {
        
        
              lemming.setNoDir(true);
              lemming.setPauseCounter(lemming.getPauseCounter() + 1);
              
   
              if (lemming.getPauseCounter() > 5) {
              
                lemming.setNoDir(false);
                
                lemming.setBridgePause(false);
              
              }
              
                
        
        } if (lemming.isBlocker()) {
           if (!(lemming.isBlocking())) {
              lemming.block();
                lemming.setDigger(false);
                lemming.setNoDir(true);
           }
        } if (false) { 
        //lemming.isExploder() && false) {
                lemming.explode();
                lemming.setNoDir(true);
        } if (lemming.isFloater()) {
                lemming.floatt();
                lemming.setFallDying(false);
                lemming.resetFallCounter();
        } if (lemming.isBasher()) { /////
                
            lemming.bash(lemming.getRightDir());
        } if (lemming.isMiner()) {
                lemming.mine();
                return;
        } if (lemming.isBridger() && !((Color.black).getRGB() 
        == lemming.getBottomColor(0))) {
                lemming.bridge();
        } if ((((lemming.isClimber() 
        && lemming.climbable(lemming.getRightDir())) 
        ///wtf, fix this  rightdir
        || lemming.isClimbing()) 
        || (lemming.isClimber() && !(lemming.climbable(lemming.getRightDir())) 
                && lemming.isClimbing()))) {
                lemming.climb(lemming.getRightDir());
                if (lemming.isClimbing()) {
                    return;
                    } if (lemming.isFalling()) {
                         if (lemming.getRightDir()) {
                            xPos -= 4;
                            } else { 
                            xPos += 4;
                        }
                        yPos += 4;     
                        lemming.setRightDir(!(lemming.getRightDir()));
                }
        } if ((Color.white).getRGB() == lemming.getBottomColor(0)) {

                lemming.setDead();

                

        } if ((Color.black).getRGB() == lemming.getBottomColor(0)) {
                    yPos += (2 + lemming.getSpeedUp());
                lemming.setFalling(true);
                lemming.setBridger(false);
            if ((Color.black).getRGB() == lemming.getBottomColor(2) 
            && !(lemming.isFloater())) {
                   yPos += 4;                       
                lemming.setDigger(false);
                lemming.setClimbing(false);
                lemming.setFalling(true);
            } else if (lemming.isFloater()) {
                yPos--;
                lemming.setDigger(false);
               } else {
                lemming.setFalling(false);
            }
        } else if ((Color.black).getRGB() != lemming.getRightColor() 
        && lemming.getRightDir() && !(lemming.getNoDir())) {
                

         lemming.resetFallCounter();


                        

              if ((Color.black).getRGB() == lemming.getRightUpColor()) {
        
                    xPos += 4;
                    yPos -= 2;


              } else {
 
                                      
                   lemming.setRightDir(!(lemming.getRightDir()));

                   xPos -= 4;

                    


                   lemming.setBridger(false);


              }


        } else  if ((Color.black).getRGB() != lemming.getLeftColor() 
        && !(lemming.getRightDir()) && !(lemming.getNoDir())) {


         lemming.resetFallCounter();


         if ((Color.black).getRGB() == lemming.getLeftUpColor()) {
        
                    xPos -= 4;
                    yPos -= 2;


         } else {

            lemming.setRightDir(!(lemming.getRightDir()));

            xPos += 4;

           lemming.setBridger(false);
        
        }


        } else {
        
                lemming.resetFallCounter();


            if ((lemming.getRightDir()) && !(lemming.getNoDir())) {
                                

                xPos += (4 + lemming.getSpeedUp());

             

            } else if (!(lemming.getRightDir()) && !(lemming.getNoDir())) {



                xPos -= (4 + lemming.getSpeedUp());


            }

            

        }



    

        lemming.setXPos(xPos);
        lemming.setYPos(yPos);

        //}

        
    }

/*    System.out.println(lemming.getCanvasX() + " " + 
lemming.getCanvasY() + " " + lemming.getXPos() + " " + lemming.getYPos());*/

        /// This is the off screen part ///
        
       /* if(xPos >= lemming.getCanvasX() || yPos >= lemming.getCanvasY() ||
           xPos < 0 || yPos < 0) {


              lemming.setDead();

        } else { */


        ///this needs to be fixed. ///

        ///along with the indestructable surfaces///
        
        

}



