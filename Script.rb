#===============================================================================
# * Roulette Minigame - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It's the Roulette Game Corner minigame
# from Ruby/Sapphire/Emerald. This minigame isn't an exact adaptation of the
# official one, the ball never stops at an occupied slot, so there's no
# Taillow and Shroomish bonus.
#
#== INSTALLATION ===============================================================
#
# Put it above main or convert into a plugin. Create "Roulette" folder at 
# Graphics/UI and put the images (may works with other sizes):
# -  30x30  ball
# -  16x16  ballicon 
# -  16x16  ballusedicon
# - 116x56  creditbox
# -  56x32  multiplierbox
# - 306x306 roulette
# - 240x46  selectedcolor
# -  46x46  selectedsingle
# -  46x192 selectedspecies
# - 244x196 table  
#
# Add on Audio/SE "Roulette Ball" and "Roulette Ball End" audio files.
#
#== HOW TO USE =================================================================
#
# Use the script command 'Roulette.start(X)' where X is the wager number.
#
# You can use 'Roulette.start(1, Roulette::BLUE)' to start the game with a 
# different board color set. Available color sets are RED, GREEN and BLUE.
#
#== NOTES ======================================================================
#
# Besides the already defined constants, you can pass any two position color
# array as the second parameter. The first color is the background, the second
# is the used ball icon.
#
#===============================================================================

if defined?(PluginManager) && !PluginManager.installed?("Roulette Minigame")
  PluginManager.register({                                                 
    :name    => "Roulette Minigame",                                        
    :version => "1.1.5",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=318598",             
    :credits => "FL"
  })
end

module Roulette
  RED   = [Color.new(0xc0,0x20,0x50), Color.new(0xf8,0x98,0xa0)]
  GREEN = [Color.new(0x51,0x96,0x31), Color.new(0x84,0xdd,0x57)]
  BLUE  = [Color.new(0x20,0x50,0xc0), Color.new(0x98,0xa0,0xf8)]
  
  TABLE_POSITIONS=[
    [1,10, 7,4],
    [5, 2,11,8],
    [9, 6, 3,0]
  ]
  COLUMNS=4
  ROWS=3
  ROUNDS=6 # Before clean the board
    
  class Cursor
    attr_reader :sprite
    attr_reader :indexX
    attr_reader :indexY
    
    def initialize(sprite,playedBalls,tableX,tableY)
      @sprite=sprite
      @sprite.x=8
      @sprite.y=8
      @playedBalls=playedBalls
      @tableX=tableX
      @tableY=tableY
      @blinkTimeCounter=0
      @indexX=-1
      @indexY=-1
      setIndex(1,1)
    end  
    
    def update
      updateBlink
    end 

    def updateBlink
      @blinkTimeCounter+=Bridge.delta
      if @blinkTimeCounter>=0.4
        @sprite.visible=!@sprite.visible
        @blinkTimeCounter=0
      end
    end
    
    def resetFlash
      @blinkTimeCounter=0
      @sprite.visible=true
    end
    
    def moveUp;   setIndex(@indexX,@indexY-1);end  
    def moveDown; setIndex(@indexX,@indexY+1);end  
    def moveLeft; setIndex(@indexX-1,@indexY);end  
    def moveRight;setIndex(@indexX+1,@indexY);end  
    
    def setIndex(x,y)
      pbPlayCursorSE if @indexX!=-1 # Ignores first time
      x%=COLUMNS+1
      y%=ROWS+1
      # Small adjustment
      if @indexY==0 && x==0
        x = @indexX==1 ? COLUMNS : 1
      end
      if @indexX==0 && y==0
        y = @indexY==1 ? ROWS : 1
      end
      # Change index format 
      if x==0 && @indexX!=0 
        @sprite.setBitmap("Graphics/UI/Roulette/selectedcolor")
      end
      if y==0 && @indexY!=0
        @sprite.setBitmap("Graphics/UI/Roulette/selectedspecies")
      end
      if (y!=0 && @indexY<=0) || (x!=0 && @indexX<=0)
        @sprite.setBitmap("Graphics/UI/Roulette/selectedsingle")
      end  
      @indexX = x
      @indexY = y
      refreshSpritePos
      resetFlash
    end

    def refreshSpritePos(extraX=0)
      @sprite.x=@tableX-2+@indexX*48+extraX
      @sprite.x+=4 if @indexX==0 
      @sprite.y=@tableY-2+@indexY*48
      @sprite.y+=4 if @indexY==0 
    end
    
    def bentPositions
      if @indexX==0
        return TABLE_POSITIONS[@indexY-1]
      elsif @indexY==0
        return TABLE_POSITIONS.transpose[@indexX-1]
      else
        return [TABLE_POSITIONS[@indexY-1][@indexX-1]]    
      end    
    end 
    
    def multiplier # Picks the multiplier value
      checkedPositions=[]
      if @indexX==0
        checkedPositions=@playedBalls[(@indexY-1)*COLUMNS,COLUMNS]
      elsif @indexY==0
        for i in 0...ROWS
          checkedPositions.push(@playedBalls[@indexX-1+i*COLUMNS])
        end  
      else
        checkedPositions.push(@playedBalls[@indexX-1+(@indexY-1)*COLUMNS])
      end  
      div=Roulette.count(checkedPositions,false)
      result=0
      result=COLUMNS*ROWS/div if div!=0
      return result
    end  
  end  
  
  class RouletteObject
    attr_reader :roulette # Sprite
    attr_reader :balls # Sprite Array
    
    def initialize(roulette)
      @roulette=roulette
      @balls=[]
      @ballHeights=[]
    end   
    
    def addBall(sprite)
      sprite.x=roulette.x
      sprite.y=roulette.y
      sprite.visible=true
      sprite.angle=@roulette.angle-10
      balls.push(sprite)
    end  
    
    def clearBalls
      for i in 0...@balls.size
        @balls[i].visible=false
        @ballHeights[i]=nil
      end  
      @balls.clear
    end 
    
    # Redraws the bitmap with the height and the changed ox and oy where
    # the ball picture will be at the top to create the illusion that the
    # ball is spinning.
    # The lower the height, the lower the distance to the roulette center.
    def adjustBitmapBall(i,height)
      return if @ballHeights[i]==height
      @ballHeights[i]=height
      bitmapBall = Bitmap.new("Graphics/UI/Roulette/ball")
      @balls[i].bitmap=Bitmap.new(30,height)
      @balls[i].bitmap.blt(0,0,bitmapBall,bitmapBall.rect)
      @balls[i].ox=balls[i].bitmap.width/2
      @balls[i].oy=balls[i].bitmap.height
    end  
    
    def x=(value)
      @roulette.x=value
      for ball in @balls
        ball.x=value
      end  
    end
    
    def y=(value)
      @roulette.y=value
    end
    
    def sumAngle(value)
      @roulette.angle+=value
      for ball in @balls
        ball.angle+=value
      end  
    end  
    
    def update
      sumAngle(80.0*Bridge.delta)
    end  
  end

  class Scene
    def startScene(wager, backgroundColor, usedIconColor)
      @sprites={} 
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=99999
      @backgroundColor=backgroundColor
      @usedIconColor=usedIconColor
      @sprites["background"]=IconSprite.new(0,0,@viewport)
      @sprites["background"].bitmap=Bitmap.new(Graphics.width,Graphics.height)
      @sprites["background"].bitmap.fill_rect(0,0,
        @sprites["background"].bitmap.width, 
        @sprites["background"].bitmap.height, @backgroundColor
      )
      @sprites["roulette"]=IconSprite.new(0,0,@viewport)
      @sprites["roulette"].setBitmap("Graphics/UI/Roulette/roulette")    
      @sprites["roulette"].ox=@sprites["roulette"].bitmap.width/2
      @sprites["roulette"].oy=@sprites["roulette"].bitmap.height/2
      @roulette=RouletteObject.new(@sprites["roulette"])
      @sprites["table"]=IconSprite.new(0,0,@viewport)
      @sprites["table"].setBitmap("Graphics/UI/Roulette/table")
      @sprites["multiplierbox"]=IconSprite.new(0,0,@viewport)
      @sprites["multiplierbox"].setBitmap("Graphics/UI/Roulette/multiplierbox")
      @sprites["multiplierbox"].z=1
      @multiplierBoxUnclampedX = @sprites["multiplierbox"].x
      @sprites["creditbox"]=IconSprite.new(0,0,@viewport)
      @sprites["creditbox"].setBitmap("Graphics/UI/Roulette/creditbox")
      @sprites["creditbox"].x=Graphics.width-@sprites["creditbox"].bitmap.width-6
      @sprites["creditbox"].y=6
      @sprites["creditbox"].z=1
      for i in 0...ROUNDS
        @sprites["ball#{i}"]=IconSprite.new(0,0,@viewport)
        @sprites["ball#{i}"].visible=false
        @sprites["balltable#{i}"]=IconSprite.new(0,0,@viewport)
        @sprites["balltable#{i}"].setBitmap("Graphics/UI/Roulette/ball")
        @sprites["balltable#{i}"].visible=false
        @sprites["ballicon#{i}"]=IconSprite.new(0,0,@viewport)
        @sprites["ballicon#{i}"].setBitmap("Graphics/UI/Roulette/ballicon")
        # Right to left
        @sprites["ballicon#{i}"].x=(@sprites["creditbox"].x+10+(ROUNDS-i-1)*16)
        @sprites["ballicon#{i}"].y=(
            @sprites["creditbox"].y+@sprites["creditbox"].bitmap.height+2
        )
      end  
      @sprites["cursor"]=IconSprite.new(0,0,@viewport)
      @playedBalls=[]
      (COLUMNS*ROWS).times do
        @playedBalls.push(false)
      end
      @sprites["overlaycredits"]=BitmapSprite.new(
          Graphics.width,Graphics.height,@viewport
      )
      @sprites["overlaycredits"].z=2
      @sprites["overlaymultiplier"]=BitmapSprite.new(
          Graphics.width,Graphics.height,@viewport
      )
      @sprites["overlaymultiplier"].z=2
      pbSetSystemFont(@sprites["overlaycredits"].bitmap)
      pbSetSystemFont(@sprites["overlaymultiplier"].bitmap)
      @sprites["overlaycredits"].bitmap.font.bold=true
      @sprites["overlaymultiplier"].bitmap.font.bold=true
      @wager=wager
      @centralizeRoulette = false
      @movedDistance = 0
      @waitingMovement = false
      @degreesToSpin = 0
      @endingSpin = false
      @remainingTimeToBlink = 0
      @remainingTimeToAddCredit = 0
      @displayedCredits = Bridge.coins
      @exit=false
      @tableBallPosArray = []
      refreshBottomElementsPos
      @cursor = Cursor.new(
        @sprites["cursor"],@playedBalls,@sprites["table"].x,@sprites["table"].y
      )
      drawCredits
      pbFadeInAndShow(@sprites) { update }
      displayMessage(
        _INTL("Place your wager with the arrows, then press the C key.")
      )
      drawMultiplier
    end

    def refreshBottomElementsPos
      @cursor.refreshSpritePos(@movedDistance) if @cursor
      # Roulette
      @roulette.x = [
        @sprites["roulette"].bitmap.width/2+4 + (@movedDistance/2.0).floor,
        (Graphics.width)/2
      ].min
      @roulette.y = Graphics.height/2
      # Table
      @sprites["table"].x = (
        Graphics.width-@sprites["table"].bitmap.width-10 + @movedDistance.floor
      )
      @sprites["table"].y=Graphics.height-@sprites["table"].bitmap.height-10
      for i in 0...@tableBallPosArray.size
        @sprites["balltable#{i}"].x = (
          @tableBallPosArray[i][0] + @movedDistance.floor
        )
        @sprites["balltable#{i}"].y = @tableBallPosArray[i][1]
      end
      # Multiplier
      baseMultiplierBoxX = @sprites["table"].x-14
      @sprites["multiplierbox"].x = [
        baseMultiplierBoxX,
        Graphics.width-@sprites["multiplierbox"].bitmap.width-10
      ].min
      @sprites["multiplierbox"].y=@sprites["table"].y+6
      @sprites["overlaymultiplier"].x = (
        @movedDistance.floor + @sprites["multiplierbox"].x - baseMultiplierBoxX
      )
    end
    
    def update
      pbUpdateSpriteHash(@sprites)
      @cursor.update
      @roulette.update
      @remainingTimeToAddCredit -= Bridge.delta
      if @displayedCredits < Bridge.coins && @remainingTimeToAddCredit <= 0
        addDisplayedCredit
      end
    end

    def addDisplayedCredit
      @remainingTimeToAddCredit = 0.075
      @displayedCredits+=1
      drawCredits
    end
    
    def drawMultiplier
      overlay=@sprites["overlaymultiplier"].bitmap
      overlay.clear     
      multiplier=@cursor.multiplier
      return if multiplier==0
      baseColor = {
        6 => Color.new(0xf7,0xc7,0x0e), # Yellow
        4 => Color.new(0xc1,0xa1,0xf4), # Purple
        3 => Color.new(0xf8,0xf8,0xf8), # White
      }.fetch(multiplier, Color.new(0xf8,0xa8,0x88)) # Default Red
      textPosition=[multiplier.to_s,
        @sprites["multiplierbox"].x+@sprites["multiplierbox"].bitmap.width-8,
        @sprites["multiplierbox"].y+6,true,baseColor,Color.new(0x60,0x60,0x70)
      ]
      Bridge.drawTextPositions(overlay,[textPosition])
    end

    def drawCredits
      overlay=@sprites["overlaycredits"].bitmap
      overlay.clear     
      textPosition=[@displayedCredits.to_s,
          @sprites["creditbox"].x+@sprites["creditbox"].bitmap.width-26,
          @sprites["creditbox"].y+32,
          true,Color.new(248,248,248),Color.new(0,0,0)
      ]
      Bridge.drawTextPositions(overlay,[textPosition])
    end
    
    # Adds the coins and updates the credit box. Return false if coins+number<0
    def addCredits(number, instant=true)
      return false if Bridge.coins+number<0
      Bridge.coins = [
        Bridge.maxCoins, Bridge.coins+number
      ].min
      if instant
        @displayedCredits = Bridge.coins
        drawCredits
      end
      return true
    end  
    
    def displayMessage(message)
      Bridge.message(message){update}
    end  
    
    def confirmMessage(message)
      return Bridge.confirmMessage(message){update}
    end  
    
    def main
      loop do
        Graphics.update
        Input.update
        self.update
        if @remainingTimeToBlink>0
          blink
        elsif @waitingMovement
          movePictures
        elsif @degreesToSpin>0
          spinRoulette
        else
          if Input.trigger?(Input::C) 
            if @cursor.multiplier!=0
              pbSEPlay(Bridge.getAudioName("Slots coin"))
              addCredits(-@wager)
              @centralizeRoulette = !@centralizeRoulette
              @waitingMovement = true
            else  
              pbPlayBuzzerSE()
            end
          end
          break if @exit
          if Input.trigger?(Input::UP);   @cursor.moveUp;   drawMultiplier;end 
          if Input.trigger?(Input::DOWN); @cursor.moveDown; drawMultiplier;end 
          if Input.trigger?(Input::LEFT); @cursor.moveLeft; drawMultiplier;end 
          if Input.trigger?(Input::RIGHT);@cursor.moveRight;drawMultiplier;end 
        end   
      end 
    end
    
    def movePictures
      speed = 480*Bridge.delta
      speed *= - 1 if !@centralizeRoulette # Reverse the way
      @movedDistance=[speed+@movedDistance,0].max
      refreshBottomElementsPos
      # The conditions for finish centralize and decentralize
      if ( 
        @centralizeRoulette && Graphics.width<(@sprites["table"].x) ||
        !@centralizeRoulette && @movedDistance==0
      )
        @waitingMovement = false
        @centralizeRoulette ? startSpin : endSpin
      end
    end 
    
    SPINS=[60*30,36*20,30*10,20*3] # Spins quantity and tiers
    
    def startSpin
      i=Roulette.count(@playedBalls,true)
      @sprites["ballicon#{i}"].setBitmap("Graphics/UI/Roulette/ballusedicon")
      @sprites["ballicon#{i}"].color=@usedIconColor
      @result=-1    
      loop do
        @result = rand(@playedBalls.size)
        break if !@playedBalls[@result]
      end
      @roulette.addBall(@sprites["ball#{i}"])
      @roulette.adjustBitmapBall(i,148)    
      @variableDegrees=10*3*TABLE_POSITIONS.flatten[@result]+SPINS[3]
      @degreesToSpin=SPINS[0]+SPINS[1]+SPINS[2]+@variableDegrees
      @endingSpin=false
      pbSEPlay(Bridge.getAudioName("Roulette Ball"))
    end
    
    def spinRoulette
      i=Roulette.count(@playedBalls,true)
      # Spins tier speeds
      if @degreesToSpin>SPINS[1]+SPINS[2]+@variableDegrees
        degrees=1200
      elsif @degreesToSpin>SPINS[2]+@variableDegrees
        degrees=800
      elsif @degreesToSpin>@variableDegrees
        degrees=400
      elsif @degreesToSpin>0
        degrees=120
      end
      angleGain=[degrees*Bridge.delta,@degreesToSpin].min
      @sprites["ball#{i}"].angle-=angleGain
      @degreesToSpin-=angleGain
      # Makes the ball more near of the center after some spins
      minDegreePerHeights = {
        128 => SPINS[1]+SPINS[2]+@variableDegrees,
        118 => SPINS[1]/2+SPINS[2]+@variableDegrees,
        108 => SPINS[2]+@variableDegrees,
        98  => SPINS[2]/2+@variableDegrees,
        88  => @variableDegrees,
        74  => 0,
      }
      for height in minDegreePerHeights.keys.sort
        next if @degreesToSpin > minDegreePerHeights[height]
        @roulette.adjustBitmapBall(i,height)
        break
      end
      # Play ending SFX
      if !@endingSpin && @degreesToSpin<=SPINS[2]+@variableDegrees
        @endingSpin = true
        pbSEStop
        pbSEPlay(Bridge.getAudioName("Roulette Ball End"))
      end
      if @degreesToSpin==0 # End
        pbSEPlay(Bridge.getAudioName("Battle ball drop"))
        @centralizeRoulette = !@centralizeRoulette
        @waitingMovement = true
      end  
    end
    
    BLINK_TIMES = 4
    SECONDS_PER_BLINK = 0.1
    BLINK_LAST_WAIT = 0.05

    def endSpin
      @tableBallPosArray.push([
        6+@sprites["table"].x+(@result%COLUMNS+1)*48, 
        6+@sprites["table"].y+(@result/COLUMNS+1)*48
      ])
      @remainingTimeToBlink = (BLINK_TIMES+BLINK_LAST_WAIT)*SECONDS_PER_BLINK*2
      refreshBottomElementsPos
    end

    def blink
      i=Roulette.count(@playedBalls,true)
      @remainingTimeToBlink-=Bridge.delta
      lastWait = @remainingTimeToBlink / SECONDS_PER_BLINK <= BLINK_LAST_WAIT
      @sprites["balltable#{i}"].visible = (
        (@remainingTimeToBlink / SECONDS_PER_BLINK).floor % 2 == 0 || lastWait
      )
      processResults if @remainingTimeToBlink<=0
    end

    def processResults
      wins = @cursor.bentPositions.include?(TABLE_POSITIONS.flatten[@result])
      if wins
        if @cursor.multiplier==12
          displayMessage(_INTL(
            "\\me[{1}]Jackpot!\\wtnp[50]", Bridge.getAudioName("Slots big win")
          ))
        else
          displayMessage(_INTL(
            "\\me[{1}]It's a hit!\\wtnp[30]", Bridge.getAudioName("Slots win")
          ))
        end
        addCredits(@wager*@cursor.multiplier, false)
        displayMessage(_INTL("You've won {1} Coins!",@wager*@cursor.multiplier))
      else  
        pbPlayBuzzerSE()
        displayMessage(_INTL("Nothing doing!"))
      end
      @playedBalls[@result]=true
      if Roulette.count(@playedBalls,true)==ROUNDS # Clear
        displayMessage(_INTL("The Roulette board will be cleared."))
        @roulette.clearBalls
        @playedBalls.clear
        @tableBallPosArray.clear
        (COLUMNS*ROWS).times do
          @playedBalls.push(false)
        end  
        for i in 0...ROUNDS
          @sprites["balltable#{i}"].visible=false
          @sprites["ballicon#{i}"].setBitmap("Graphics/UI/Roulette/ballicon")
          @sprites["ballicon#{i}"].color=Color.new(0,0,0,0)
        end  
      end  
      drawMultiplier
      if confirmMessage(_INTL("Keep playing?"))
        if Bridge.coins<@wager
          displayMessage(_INTL("You don't have enough Coins to play!"))
          @exit=true 
        end
      else  
        @exit=true 
      end  
    end

    def endScene
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
    end
  end

  class Screen
    def initialize(scene)
      @scene=scene
    end

    def startScreen(wager, backgroundAndIconColor)
      backgroundAndIconColor ||= RED 
      @scene.startScene(
        wager,backgroundAndIconColor[0],backgroundAndIconColor[1]
      )
      @scene.main
      @scene.endScene
    end
  end
  
  # Added since Ruby 1.8 Array class doesn't have count
  def self.count(array, value)
    ret=0
    for element in array
      ret+=1 if element==value
    end
    return ret
  end 

  def self.start(wager=1, backgroundAndIconColor=nil)
    if !Bridge.hasCoinCase?
      Bridge.message(_INTL("It's a Roulette."))
    elsif Bridge.confirmMessage(_INTL(
      "\\CNThe minimum wanger at this table is {1}. Do you want to play?", wager
    ))
      if Bridge.coins<wager
        Bridge.message(_INTL("You don't have enough Coins to play!"))
      elsif Bridge.coins==Bridge.maxCoins
        Bridge.message(_INTL("Your Coin Case is full!"))  
      else
        pbFadeOutIn(99999){     
          scene=Scene.new
          screen=Screen.new(scene)
          screen.startScreen(wager, backgroundAndIconColor)
        }
      end
    end
  end

  # Essentials multiversion layer
  module Bridge
    @@audioNameHash = nil
    module_function

    def major_version
      ret = 0
      if defined?(Essentials)
        ret = Essentials::VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALS_VERSION)
        ret = ESSENTIALS_VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALSVERSION)
        ret = ESSENTIALSVERSION.split(".")[0].to_i
      end
      return ret
    end

    MAJOR_VERSION = major_version

    def delta
      return 0.025 if MAJOR_VERSION < 21
      return Graphics.delta
    end

    def message(string, &block)
      return Kernel.pbMessage(string, &block) if MAJOR_VERSION < 20
      return pbMessage(string, &block)
    end

    def confirmMessage(string, &block)
      return Kernel.pbConfirmMessage(string, &block) if MAJOR_VERSION < 20
      return pbConfirmMessage(string, &block)
    end

    def drawTextPositions(bitmap,textpos)
      if MAJOR_VERSION < 20
        for singleTextPos in textpos
          singleTextPos[2] -= MAJOR_VERSION==19 ? 12 : 6
        end
      end
      return pbDrawTextPositions(bitmap,textpos)
    end
    
    def coinHolder
      return case MAJOR_VERSION
        when 0..18; $PokemonGlobal
        when 19;    $Trainer
        else        $player
      end
    end

    def coins
      return coinHolder.coins
    end

    def coins=(value)
      coinHolder.coins = value
    end

    def maxCoins
      return case MAJOR_VERSION
        when 0..17; MAXCOINS
        when 18;    MAX_COINS
        else        Settings::MAX_COINS
      end
    end

    def hasCoinCase?
      return case MAJOR_VERSION
        when 0..18; $PokemonBag.pbQuantity(PBItems::COINCASE) > 0
        when 19;    $PokemonBag.pbHasItem?(:COINCASE)
        else        $bag.has?(:COINCASE)
      end
    end

    def getAudioName(baseName)
      if !@@audioNameHash
        if MAJOR_VERSION < 17
          @@audioNameHash = {
            "Battle ball drop" => "balldrop"   ,
            "Slots coin"       => "SlotsCoin"  ,
            "Slots win"        => "SlotsWin"   ,
            "Slots big win"    => "SlotsBigWin",
          }
        else
          @@audioNameHash = {}
        end
      end
      return @@audioNameHash.fetch(baseName, baseName)  
    end
  end
end