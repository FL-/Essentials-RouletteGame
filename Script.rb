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
# To this script works, put it above main or convert into a plugin. Create 
# "Roulette" folder at Graphics/Pictures and put the pictures (may works with
# other sizes):
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
#=== HOW TO USE ================================================================
#
# Use the script command 'pbRoulette(X)' where X is the wager number.
#
#===============================================================================

if defined?(PluginManager) && !PluginManager.installed?("Roulette Minigame")
  PluginManager.register({                                                 
    :name    => "Roulette Minigame",                                        
    :version => "1.0.2",                                                     
    :link    => "https://www.pokecommunity.com/showthread.php?t=318598",             
    :credits => "FL"
  })
end

class RouletteScene
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
      @frameCount=0
      @indexX=-1
      @indexY=-1
      setIndex(1,1)
    end  
    
    def update
      @frameCount+=1
      @sprite.visible=!@sprite.visible if @frameCount%16==0 # Flash effect
    end  
    
    def resetframeCount
      @frameCount=0
      @sprite.visible=true
    end
    
    def moveUp;   setIndex(@indexX,@indexY-1);end  
    def moveDown; setIndex(@indexX,@indexY+1);end  
    def moveLeft; setIndex(@indexX-1,@indexY);end  
    def moveRight;setIndex(@indexX+1,@indexY);end  
    
    def setIndex(x,y)
      pbPlayCursorSE() if @indexX!=-1 # Ignores first time
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
        @sprite.setBitmap("Graphics/Pictures/Roulette/selectedcolor")
      end
      if y==0 && @indexY!=0
        @sprite.setBitmap("Graphics/Pictures/Roulette/selectedspecies")
      end
      if (y!=0 && @indexY<=0) || (x!=0 && @indexX<=0)
        @sprite.setBitmap("Graphics/Pictures/Roulette/selectedsingle")
      end  
      @indexX = x
      @indexY = y
      @sprite.x=@tableX-2+@indexX*48
      @sprite.x+=4 if @indexX==0 
      @sprite.y=@tableY-2+@indexY*48
      @sprite.y+=4 if @indexY==0 
      resetframeCount
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
      div=RouletteScreen.count(checkedPositions,false)
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
    end   
    
    def addBall(sprite)
      sprite.x=roulette.x
      sprite.y=roulette.y
      sprite.visible=true
      sprite.angle=@roulette.angle-10
      balls.push(sprite)
    end  
    
    def clearBalls
      for ball in @balls
        ball.visible=false
      end  
      @balls.clear
    end 
    
    # Redraws the bitmap with the height and the changed ox and oy where
    # the ball picture will be at the top to create the illusion that the
    # ball is spinning.
    # The lower the height, the lower the distance to the roulette center.
    def adjustBitmapBall(i,height)
      bitmapBall = Bitmap.new("Graphics/Pictures/Roulette/ball")
      @balls[i].bitmap=Bitmap.new(30,height)
      @balls[i].bitmap.blt(0,0,bitmapBall,bitmapBall.rect)
      @balls[i].ox=balls[i].bitmap.width/2
      @balls[i].oy=balls[i].bitmap.height
    end  
    
    def sumX(value)
      @roulette.x+=value
      for ball in @balls
        ball.x+=value
      end  
    end
    
    def sumAngle(value)
      @roulette.angle+=value
      for ball in @balls
        ball.angle+=value
      end  
    end  
    
    def update
      sumAngle(2)
    end  
  end  
  
  def update
    pbUpdateSpriteHash(@sprites)
    @cursor.update
    @roulette.update
  end
  
  def pbStartScene(wager)
    @sprites={} 
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=99999
    # To change the board color and the used icon color, just change the two
    # below variable. You can set conditions like the wager at official games.
    @backgroundColor=Color.new(192,32,80)
    @usedIconColor=Color.new(248,152,160)
#    if wager>=3 # Activates second table color values
#      @backgroundColor=Color.new(80,192,32) 
#      @usedIconColor=Color.new(160,248,152)
#    end
    @sprites["background"]=IconSprite.new(0,0,@viewport)
    @sprites["background"].bitmap=Bitmap.new(Graphics.width,Graphics.height)
    @sprites["background"].bitmap.fill_rect(0,0,
      @sprites["background"].bitmap.width, 
      @sprites["background"].bitmap.height, @backgroundColor
    )
    @sprites["roulette"]=IconSprite.new(0,0,@viewport)
    @sprites["roulette"].setBitmap("Graphics/Pictures/Roulette/roulette")
    @sprites["roulette"].x=@sprites["roulette"].bitmap.width/2+4
    @sprites["roulette"].y=Graphics.height/2    
    @sprites["roulette"].ox=@sprites["roulette"].bitmap.width/2
    @sprites["roulette"].oy=@sprites["roulette"].bitmap.height/2
    @roulette=RouletteObject.new(@sprites["roulette"])
    @sprites["table"]=IconSprite.new(0,0,@viewport)
    @sprites["table"].setBitmap("Graphics/Pictures/Roulette/table")
    @sprites["table"].x=Graphics.width-@sprites["table"].bitmap.width-16
    @sprites["table"].y=Graphics.height-@sprites["table"].bitmap.height-16
    @sprites["multiplierbox"]=IconSprite.new(0,0,@viewport)
    @sprites["multiplierbox"].setBitmap(
      "Graphics/Pictures/Roulette/multiplierbox"
    )
    @sprites["multiplierbox"].x=@sprites["table"].x-12
    @sprites["multiplierbox"].y=@sprites["table"].y+6
    @sprites["creditbox"]=IconSprite.new(0,0,@viewport)
    @sprites["creditbox"].setBitmap("Graphics/Pictures/Roulette/creditbox")
    @sprites["creditbox"].x=Graphics.width-@sprites["creditbox"].bitmap.width-8
    @sprites["creditbox"].y=8
    for i in 0...ROUNDS
      @sprites["ball#{i}"]=IconSprite.new(0,0,@viewport)
      @sprites["ball#{i}"].visible=false
      @sprites["balltable#{i}"]=IconSprite.new(0,0,@viewport)
      @sprites["balltable#{i}"].setBitmap("Graphics/Pictures/Roulette/ball")
      @sprites["balltable#{i}"].visible=false
      @sprites["ballicon#{i}"]=IconSprite.new(0,0,@viewport)
      @sprites["ballicon#{i}"].setBitmap("Graphics/Pictures/Roulette/ballicon")
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
    @cursor = Cursor.new(
      @sprites["cursor"],@playedBalls,@sprites["table"].x,@sprites["table"].y
    )
    @sprites["overlaycredits"]=BitmapSprite.new(
        Graphics.width,Graphics.height,@viewport
    )
    @sprites["overlaymultiplier"]=BitmapSprite.new(
        Graphics.width,Graphics.height,@viewport
    )
    pbSetSystemFont(@sprites["overlaycredits"].bitmap)
    pbSetSystemFont(@sprites["overlaymultiplier"].bitmap)
    @sprites["overlaycredits"].bitmap.font.bold=true
    @sprites["overlaymultiplier"].bitmap.font.bold=true
    @wager=wager
    @centralizeRoulette = false
    @movedDistance = 0
    @waitingMovement = false
    @degreesToSpin = 0
    @exit=false
    pbDrawCredits
    pbFadeInAndShow(@sprites) { update }
    displayMessage(
	  _INTL("Place your wager with the arrows, then press the C key.")
	)
    pbDrawMultiplier
  end
  
  def pbDrawMultiplier
    overlay=@sprites["overlaymultiplier"].bitmap
    overlay.clear     
    multiplier=@cursor.multiplier
    return if multiplier==0
    textPosition=[multiplier.to_s,
       @sprites["multiplierbox"].x+@sprites["multiplierbox"].bitmap.width-8,
       @sprites["multiplierbox"].y-6,
       true,Color.new(248,168,136),Color.new(96,96,112)
    ]
    RouletteBridge.drawTextPositions(overlay,[textPosition])
  end

  def pbDrawCredits
    overlay=@sprites["overlaycredits"].bitmap
    overlay.clear     
    textPosition=[RouletteBridge.coins.to_s,
        @sprites["creditbox"].x+@sprites["creditbox"].bitmap.width-26,
        @sprites["creditbox"].y+20,
        true,Color.new(248,248,248),Color.new(0,0,0)
    ]
    RouletteBridge.drawTextPositions(overlay,[textPosition])
  end
  
  # Adds the coins and updates the credit box. Return false if coins+number<0
  def pbAddCredits(number)
    return false if RouletteBridge.coins+number<0
    RouletteBridge.coins = [
      RouletteBridge.getMaxCoins, RouletteBridge.coins+number
    ].min
    pbDrawCredits
    return true
  end  
  
  def displayMessage(message)
    Kernel.pbMessage(message){update}
  end  
  
  def pbConfirmMessage(message)
    return Kernel.pbConfirmMessage(message){update}
  end  
  
  def pbMain
    loop do
      Graphics.update
      Input.update
      self.update
      if @waitingMovement
        pbMovePictures
      elsif @degreesToSpin>0
        pbSpinRoulette
      else
        if Input.trigger?(Input::C) 
          if @cursor.multiplier!=0 # Valid bent
            pbSEPlay(RouletteBridge.getAudioName("Slots coin"))
            pbAddCredits(-@wager)
            @centralizeRoulette = !@centralizeRoulette
            @waitingMovement = true
          else  
            pbPlayBuzzerSE()
          end
        end
        break if @exit
        if Input.trigger?(Input::UP);   @cursor.moveUp;   pbDrawMultiplier;end 
        if Input.trigger?(Input::DOWN); @cursor.moveDown; pbDrawMultiplier;end 
        if Input.trigger?(Input::LEFT); @cursor.moveLeft; pbDrawMultiplier;end 
        if Input.trigger?(Input::RIGHT);@cursor.moveRight;pbDrawMultiplier;end 
      end   
    end 
  end
  
  def pbMovePictures
    speed = 12
    speed *= - 1 if !@centralizeRoulette # Reverse the way
    @roulette.sumX(speed/3)
    @sprites["table"].x+=speed
    for i in 0...RouletteScreen.count(@playedBalls,true)
      @sprites["balltable#{i}"].x+=speed
    end
    @sprites["multiplierbox"].x+=speed
    @sprites["cursor"].x+=speed
    @sprites["overlaymultiplier"].x+=speed
    @movedDistance+=speed 
    # The conditions for finish centralize and decentralize
    if ( 
      @centralizeRoulette && Graphics.width<(@sprites["table"].x+48) ||
      !@centralizeRoulette && @movedDistance==0
    )
      @waitingMovement = false
      @centralizeRoulette ? pbStartSpin : pbEndSpin
    end
  end  
  
  SPINS=[60*30,36*20,30*10,20*3] # Spins quantity and tiers
  
  def pbStartSpin
    i=RouletteScreen.count(@playedBalls,true)
    @sprites["ballicon#{i}"].setBitmap(
      "Graphics/Pictures/Roulette/ballusedicon"
    )
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
    # Rolling Ball ME should starts here.
  end
  
  def pbSpinRoulette
    i=RouletteScreen.count(@playedBalls,true)
    # Spins tier speeds
    if @degreesToSpin>SPINS[1]+SPINS[2]+@variableDegrees
      degrees=30
    elsif @degreesToSpin>SPINS[2]+@variableDegrees
      degrees=20
    elsif @degreesToSpin>@variableDegrees
      degrees=10
    elsif @degreesToSpin>0
      degrees=3
    end  
    @sprites["ball#{i}"].angle-=degrees
    @degreesToSpin-=degrees
    # Makes the ball more near of the center after some spins
    height=0
    if @degreesToSpin==0
      height=74
    elsif @degreesToSpin==@variableDegrees
      height=88
    elsif @degreesToSpin==SPINS[2]/2+@variableDegrees
      height=98
    elsif @degreesToSpin==SPINS[2]+@variableDegrees
      height=108
    elsif @degreesToSpin==SPINS[1]/2+SPINS[2]+@variableDegrees
      height=118
    elsif @degreesToSpin==SPINS[1]+SPINS[2]+@variableDegrees
      height=128
    end
    @roulette.adjustBitmapBall(i,height) if height!=0
    if @degreesToSpin==0 # End
      # Rolling Ball BGS should stops here.
      pbSEPlay(RouletteBridge.getAudioName("Battle ball drop"))
      @centralizeRoulette = !@centralizeRoulette
      @waitingMovement = true
    end  
  end  
  
  def pbEndSpin
    i=RouletteScreen.count(@playedBalls,true)
    @sprites["balltable#{i}"].visible=true
    @sprites["balltable#{i}"].x=6+@sprites["table"].x+(@result%COLUMNS+1)*48
    @sprites["balltable#{i}"].y=6+@sprites["table"].y+(@result/COLUMNS+1)*48
    wins = @cursor.bentPositions.include?(TABLE_POSITIONS.flatten[@result])
    if wins
      multiplier = @cursor.multiplier
      if multiplier==12
        displayMessage(_INTL(
          "\\me[{1}]Jackpot!\\wtnp[50]",
          RouletteBridge.getAudioName("Slots big win")
        ))
      else
        displayMessage(_INTL(
          "\\me[{1}]It's a hit!\\wtnp[30]",
          RouletteBridge.getAudioName("Slots win")
        ))
      end
      displayMessage(_INTL("You've won {1} Coins!",@wager*multiplier))
      pbAddCredits(@wager*multiplier)
    else  
      pbPlayBuzzerSE()
      displayMessage(_INTL("Nothing doing!"))
    end
    @playedBalls[@result]=true
    if i==(ROUNDS-1) # Clear
      displayMessage(_INTL("The Roulette board will be cleared."))
      @roulette.clearBalls
      @playedBalls.clear
      (COLUMNS*ROWS).times do
        @playedBalls.push(false)
      end  
      for index in 0...ROUNDS
        @sprites["balltable#{index}"].visible=false
        @sprites["ballicon#{index}"].setBitmap(
            "Graphics/Pictures/Roulette/ballicon"
        )
        @sprites["ballicon#{index}"].color=Color.new(0,0,0,0)
      end  
    end  
    pbDrawMultiplier
    if pbConfirmMessage(_INTL("Keep playing?"))
      if RouletteBridge.coins<@wager
        displayMessage(_INTL("You don't have enough Coins to play!"))
        @exit=true 
      end
    else  
      @exit=true 
    end  
  end  

  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end


class RouletteScreen
  # Added since Ruby 1.8 Array class doesn't have count
  def self.count(array, value)
    ret=0
    for element in array
      ret+=1 if element==value
    end
    return ret
  end  
  
  def initialize(scene)
    @scene=scene
  end

  def pbStartScreen(wager)
    @scene.pbStartScene(wager)
    @scene.pbMain
    @scene.pbEndScene
  end
end

def pbRoulette(wager=1)
  if !RouletteBridge.hasCoinCase?
    Kernel.pbMessage(_INTL("It's a Roulette."))
  elsif Kernel.pbConfirmMessage(_INTL(
    "\\CNThe minimum wanger at this table is {1}. Do you want to play?", wager
  ))
    if RouletteBridge.coins<wager
      Kernel.pbMessage(_INTL("You don't have enough Coins to play!"))
    elsif RouletteBridge.coins==RouletteBridge.getMaxCoins
      Kernel.pbMessage(_INTL("Your Coin Case is full!"))  
    else    
      scene=RouletteScene.new
      screen=RouletteScreen.new(scene)
      screen.pbStartScreen(wager)
    end
  end
end

# Essentials multiversion layer
module RouletteBridge
  @@audioNameHash = nil

  def self.v19Plus?
    return defined?(Settings) && Settings.const_defined?(:MAX_COINS)
  end

  def self.v18?
    return defined?(MAX_COINS)
  end

  def self.v17?
    return defined?(MEGARINGS)
  end

  def self.v17Plus?
    return v17? || v18? || v19Plus?
  end

  def self.coins
    return (v19Plus? ? $Trainer : $PokemonGlobal).coins
  end

  def self.coins=(value)
    (v19Plus? ? $Trainer : $PokemonGlobal).coins = value
  end

  def self.getMaxCoins
    return Settings::MAX_COINS if v19Plus?
    return MAX_COINS if v18?
    return MAXCOINS
  end

  def self.hasCoinCase?
    return $PokemonBag.pbQuantity(v19Plus? ? :COINCASE : PBItems::COINCASE) > 0
  end

  def self.drawTextPositions(bitmap,textpos)
    if !v19Plus?
      for singleTextPos in textpos
        singleTextPos[2]+=6
      end
    end
    return pbDrawTextPositions(bitmap,textpos)
  end

  def self.getAudioName(baseName)
    if !@@audioNameHash
      if !v17Plus?
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