--- Taking the lead of AI escorting your flight.
-- The ESCORT class allows you to interact with escoring AI on your flight and take the lead.
-- The following commands will be available:
-- 
-- * Pop-up and Scan Area
-- * Re-Join Formation
-- * Hold Position in x km
-- * Report identified targets
-- * Perform tasks per identified target: Report vector to target, paint target, kill target
-- 
-- @module ESCORT
-- @author FlightControl

Include.File( "Routines" )
Include.File( "Base" )
Include.File( "Database" )
Include.File( "Group" )
Include.File( "Zone" )

--- ESCORT class
-- @type ESCORT
-- @extends Base#BASE
-- @field Client#CLIENT EscortClient
-- @field Group#GROUP EscortGroup
-- @field #string EscortName
ESCORT = {
  ClassName = "ESCORT",
  EscortName = nil, -- The Escort Name
  EscortClient = nil,
  EscortGroup = nil,
  Targets = {}, -- The identified targets
}

--- MENUPARAM type
-- @type MENUPARAM
-- @field #ESCORT ParamSelf

--- ESCORT class constructor for an AI group
-- @param self
-- @param Client#CLIENT EscortClient The client escorted by the EscortGroup.
-- @param Group#GROUP EscortGroup The group AI escorting the EscortClient.
-- @param #string EscortName Name of the escort.
-- @return #ESCORT self
function ESCORT:New( EscortClient, EscortGroup, EscortName )
  local self = BASE:Inherit( self, BASE:New() )
  self:T( { EscortClient, EscortGroup, EscortName } )
  
  self.EscortClient = EscortClient
  self.EscortGroup = EscortGroup
  self.EscortName = EscortName
  self.ReportTargets = true

  self.EscortMenu = MENU_CLIENT:New( self.EscortClient, "Escort" .. self.EscortName )
 
   -- Escort Navigation  
  self.EscortMenuReportNavigation = MENU_CLIENT:New( self.EscortClient, "Navigation", self.EscortMenu )
  self.EscortMenuHoldPosition = MENU_CLIENT_COMMAND:New( self.EscortClient, "Hold Position and Stay Low", self.EscortMenuReportNavigation, ESCORT._HoldPosition, { ParamSelf = self } )
  self.EscortMenuHoldPosition = MENU_CLIENT_COMMAND:New( self.EscortClient, "Join-Up and Hold Position NearBy", self.EscortMenuReportNavigation, ESCORT._HoldPositionNearBy, { ParamSelf = self } )  

  -- Report Targets
  self.EscortMenuReportNearbyTargets = MENU_CLIENT:New( self.EscortClient, "Report targets", self.EscortMenu )
  self.EscortMenuReportNearbyTargetsOn = MENU_CLIENT_COMMAND:New( self.EscortClient, "Report targets on", self.EscortMenuReportNearbyTargets, ESCORT._ReportNearbyTargets, { ParamSelf = self, ParamReportTargets = true } )
  self.EscortMenuReportNearbyTargetsOff = MENU_CLIENT_COMMAND:New( self.EscortClient, "Report targets off", self.EscortMenuReportNearbyTargets, ESCORT._ReportNearbyTargets, { ParamSelf = self, ParamReportTargets = false, } )

  -- Scanning Targets
  self.EscortMenuScanForTargets = MENU_CLIENT:New( self.EscortClient, "Scan targets", self.EscortMenu )
  self.EscortMenuReportNearbyTargetsOn = MENU_CLIENT_COMMAND:New( self.EscortClient, "Scan targets 30 seconds", self.EscortMenuScanForTargets, ESCORT._ScanTargets30Seconds, { ParamSelf = self, ParamScanDuration = 30 } )

  -- Attack Targets
  self.EscortMenuAttackNearbyTargets = MENU_CLIENT:New( self.EscortClient, "Attack nearby targets", self.EscortMenu )
  self.EscortMenuAttackTargets =  {} 
  self.Targets = {}

  -- Rules of Engagement
  self.EscortMenuROE = MENU_CLIENT:New( self.EscortClient, "ROE", self.EscortMenu )
  self.EscortMenuROEHoldFire = MENU_CLIENT_COMMAND:New( self.EscortClient, "Hold Fire", self.EscortMenuROE, ESCORT._ROEHoldFire, { ParamSelf = self, } )
  self.EscortMenuROEReturnFire = MENU_CLIENT_COMMAND:New( self.EscortClient, "Return Fire", self.EscortMenuROE, ESCORT._ROEReturnFire, { ParamSelf = self, } )
  self.EscortMenuROEOpenFire = MENU_CLIENT_COMMAND:New( self.EscortClient, "Open Fire", self.EscortMenuROE, ESCORT._ROEOpenFire, { ParamSelf = self, } )
  self.EscortMenuROEWeaponFree = MENU_CLIENT_COMMAND:New( self.EscortClient, "Weapon Free", self.EscortMenuROE, ESCORT._ROEWeaponFree, { ParamSelf = self, } )
  
  -- Reaction to Threats
  self.EscortMenuEvasion = MENU_CLIENT:New( self.EscortClient, "Evasion", self.EscortMenu )
  self.EscortMenuEvasionNoReaction = MENU_CLIENT_COMMAND:New( self.EscortClient, "Fight until death", self.EscortMenuEvasion, ESCORT._EvasionNoReaction, { ParamSelf = self, } )
  self.EscortMenuEvasionPassiveDefense = MENU_CLIENT_COMMAND:New( self.EscortClient, "Use flares, chaff and jammers", self.EscortMenuEvasion, ESCORT._EvasionPassiveDefense, { ParamSelf = self, } )
  self.EscortMenuEvasionEvadeFire = MENU_CLIENT_COMMAND:New( self.EscortClient, "Evade enemy fire", self.EscortMenuEvasion, ESCORT._EvasionEvadeFire, { ParamSelf = self, } )
  self.EscortMenuEvasionVertical = MENU_CLIENT_COMMAND:New( self.EscortClient, "Go below radar and evade fire", self.EscortMenuEvasion, ESCORT._EvasionVertical, { ParamSelf = self, } )
  
  -- Cancel current Task
  self.EscortMenuCancelTask = MENU_CLIENT_COMMAND:New( self.EscortClient, "Cancel current task", self.EscortMenu, ESCORT._CancelCurrentTask, { ParamSelf = self, } )
  
  
  self.ScanForTargetsFunction = routines.scheduleFunction( self._ScanForTargets, { self }, timer.getTime() + 1, 30 )
end


--- @param #MENUPARAM MenuParam
function ESCORT._HoldPosition( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient
  
  EscortGroup:PushTask( EscortGroup:HoldPosition( 300 ) )
  MESSAGE:New( "Holding Position at ... for 5 minutes.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/HoldPosition" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._HoldPositionNearBy( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient
  
  --MenuParam.ParamSelf.EscortGroup:OrbitCircleAtVec2( MenuParam.ParamSelf.EscortClient:GetPointVec2(), 300, 30, 0 )
  
  local PointFrom = {}
  local GroupPoint = EscortGroup:GetPointVec2()
  PointFrom = {}
  PointFrom.x = GroupPoint.x
  PointFrom.y = GroupPoint.y
  PointFrom.speed = 250
  PointFrom.type = AI.Task.WaypointType.TURNING_POINT
  PointFrom.alt = EscortClient:GetAltitude()
  PointFrom.alt_type = AI.Task.AltitudeType.BARO

  local ClientPoint = MenuParam.ParamSelf.EscortClient:GetPointVec2()
  local PointTo = {}
  PointTo.x = ClientPoint.x
  PointTo.y = ClientPoint.y
  PointTo.speed = 250
  PointTo.type = AI.Task.WaypointType.TURNING_POINT
  PointTo.alt = EscortClient:GetAltitude()
  PointTo.alt_type = AI.Task.AltitudeType.BARO
  PointTo.task = EscortGroup:OrbitCircleAtVec2( EscortClient:GetPointVec2(), 300, 30, 0 )
  
  local Points = { PointFrom, PointTo }
  
  
  EscortGroup:PushTask( EscortGroup:TaskMission( Points ) )
  MESSAGE:New( "Rejoining to your location. Please hold at your location.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/HoldPositionNearBy" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

function ESCORT._ReportNearbyTargets( MenuParam )
  MenuParam.ParamSelf:T()
  
  MenuParam.ParamSelf.ReportTargets = MenuParam.ParamReportTargets

end

--- @param #MENUPARAM MenuParam
function ESCORT._ScanTargets30Seconds( MenuParam )
  MenuParam.ParamSelf:T()

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  EscortGroup:PushTask( EscortGroup:OrbitCircle( 30, 200, 20 ) )
  MESSAGE:New( "Scanning targets for 30 seconds.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ScanTargets30Seconds" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._ScanTargets60Seconds( MenuParam )
  MenuParam.ParamSelf:T()

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  EscortGroup:PushTask(  EscortGroup:OrbitCircle( 60, 200, 20 ) )
  MESSAGE:New( "Scanning targets for 60 seconds.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ScanTargets60Seconds" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._AttackTarget( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:AttackUnit( MenuParam.ParamUnit )
  MESSAGE:New( "Attacking Unit", MenuParam.ParamSelf.EscortName, 10, "ESCORT/AttackTarget" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._ROEHoldFire( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:HoldFire()
  MESSAGE:New( "Holding weapons.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ROEHoldFire" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._ROEReturnFire( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:ReturnFire()
  MESSAGE:New( "Returning enemy fire.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ROEReturnFire" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._ROEOpenFire( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:OpenFire()
  MESSAGE:New( "Open fire on ordered targets.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ROEOpenFire" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._ROEWeaponFree( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:WeaponFree()
  MESSAGE:New( "Engaging targets.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/ROEWeaponFree" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._EvasionNoReaction( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:EvasionNoReaction()
  MESSAGE:New( "We'll fight until death.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/EvasionNoReaction" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._EvasionPassiveDefense( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:EvasionPassiveDefense()
  MESSAGE:New( "We will use flares, chaff and jammers.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/EvasionPassiveDefense" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._EvasionEvadeFire( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:EvasionEvadeFire()
  MESSAGE:New( "We'll evade enemy fire.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/EvasionEvadeFire" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._EvasionVertical( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  MenuParam.ParamSelf.EscortGroup:EvasionVertical()
  MESSAGE:New( "We'll perform vertical evasive manoeuvres.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/EvasionVertical" ):ToClient( MenuParam.ParamSelf.EscortClient )
end

--- @param #MENUPARAM MenuParam
function ESCORT._CancelCurrentTask( MenuParam )

  local EscortGroup = MenuParam.ParamSelf.EscortGroup
  local EscortClient = MenuParam.ParamSelf.EscortClient

  EscortGroup:PopCurrentTask()
  MESSAGE:New( "Cancelling with current orders, continuing our mission.", MenuParam.ParamSelf.EscortName, 10, "ESCORT/CancelCurrentTask" ):ToClient( MenuParam.ParamSelf.EscortClient )
end


function ESCORT:_ScanForTargets()
  self:T()

  self.Targets = {}
  
  if self.EscortGroup:IsAlive() then
    local EscortTargets = self.EscortGroup:GetDetectedTargets()
    
    local EscortTargetMessages = ""
    for EscortTargetID, EscortTarget in pairs( EscortTargets ) do
      local EscortObject = EscortTarget.object
      self:T( EscortObject )
      if EscortObject and EscortObject:isExist() and EscortObject.id_ < 50000000 then
        
          local EscortTargetMessage = ""
        
          local EscortTargetUnit = UNIT:New( EscortObject )
        
          local EscortTargetCategoryName = EscortTargetUnit:GetCategoryName()
          local EscortTargetCategoryType = EscortTargetUnit:GetTypeName()
        
        
  --        local EscortTargetIsDetected, 
  --              EscortTargetIsVisible, 
  --              EscortTargetLastTime, 
  --              EscortTargetKnowType, 
  --              EscortTargetKnowDistance, 
  --              EscortTargetLastPos, 
  --              EscortTargetLastVelocity
  --              = self.EscortGroup:IsTargetDetected( EscortObject )
  --      
  --        self:T( { EscortTargetIsDetected, 
  --              EscortTargetIsVisible, 
  --              EscortTargetLastTime, 
  --              EscortTargetKnowType, 
  --              EscortTargetKnowDistance, 
  --              EscortTargetLastPos, 
  --              EscortTargetLastVelocity } )
        
          if EscortTarget.distance then
            local EscortTargetUnitPositionVec3 = EscortTargetUnit:GetPositionVec3()
            local EscortPositionVec3 = self.EscortGroup:GetPositionVec3()
            local Distance = routines.utils.get3DDist( EscortTargetUnitPositionVec3, EscortPositionVec3 ) / 1000
            self:T( { self.EscortGroup:GetName(), EscortTargetUnit:GetName(), Distance, EscortTarget.visible } )

            if Distance <= 8 then

              if EscortTarget.type then
                EscortTargetMessage = EscortTargetMessage .. " - " .. EscortTargetCategoryName .. " (" .. EscortTargetCategoryType .. ") at "
              else
                EscortTargetMessage = EscortTargetMessage .. " - Unknown target at "
              end

              EscortTargetMessage = EscortTargetMessage .. string.format( "%.2f", Distance ) .. " km"

              if EscortTarget.visible then
                EscortTargetMessage = EscortTargetMessage .. ", visual"
              end

              local TargetIndex = Distance*1000
              self.Targets[TargetIndex] = {}           
              self.Targets[TargetIndex].AttackMessage = EscortTargetMessage
              self.Targets[TargetIndex].AttackUnit = EscortTargetUnit        
            end
          end
  
          if EscortTargetMessage ~= "" then
            EscortTargetMessages = EscortTargetMessages .. EscortTargetMessage .. "\n"
          end
      end
    end
    
    if EscortTargetMessages ~= "" and self.ReportTargets == true then
      self.EscortClient:Message( EscortTargetMessages:gsub("\n$",""), 20, "/ESCORT.DetectedTargets", self.EscortName .. " reporting detected targets within 8 km range:", 0 )
    end

    self:T()
  
    self:T( { "Sorting Targets Table:", self.Targets } )
    table.sort( self.Targets )
    self:T( { "Sorted Targets Table:", self.Targets } )
    
    for MenuIndex = 1, #self.EscortMenuAttackTargets do
      self:T( { "Remove Menu:", self.EscortMenuAttackTargets[MenuIndex] } )
      self.EscortMenuAttackTargets[MenuIndex] = self.EscortMenuAttackTargets[MenuIndex]:Remove()
    end
    
    local MenuIndex = 1
    for TargetID, TargetData in pairs( self.Targets ) do
      self:T( { "Adding menu:", TargetID, "for Unit", self.Targets[TargetID].AttackUnit } )
      if MenuIndex <= 10 then
        self.EscortMenuAttackTargets[MenuIndex] = 
          MENU_CLIENT_COMMAND:New( self.EscortClient,
                                  self.Targets[TargetID].AttackMessage,
                                  self.EscortMenuAttackNearbyTargets,
                                  ESCORT._AttackTarget,
                                  { ParamSelf = self,
                                    ParamUnit = self.Targets[TargetID].AttackUnit 
                                  }
                                )
          self:T( { "New Menu:", self.EscortMenuAttackTargets[TargetID] } )
          MenuIndex = MenuIndex + 1
      else
        break
      end
    end

  else
    routines.removeFunction( self.ScanForTargetsFunction )
  end
end
