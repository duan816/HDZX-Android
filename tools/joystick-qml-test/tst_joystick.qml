import QtQuick
import QtTest
import QGroundControl
import "../../src/FlyView" as Production
TestCase {
    id: testCase
    name: "VirtualJoystickInput"
    width: 1000; height: 600; visible: true; when: windowShown
    property bool autoCenterThrottle: true
    property bool leftHandedMode: false
    Production.VirtualJoystick { id: sticks; x: 120; y: 250; width: 760; height: 150 }
    function pad(side) { return findChild(sticks, "virtualJoystick" + side + "Pad") }
    function init() {
        autoCenterThrottle = true; leftHandedMode = false
        sticks.visible = true; sticks.width = 760; sticks.height = 150
        sticks.uiTotalWidth = 0; sticks.uiRealX = 0
        QGroundControl.multiVehicleManager.activeVehicle=QGroundControl.testVehicle
        QGroundControl.testVehicle.rover = false
        sticks.keepXAxisWhileChanged()
    }
    Component { id: layerFactory; JoystickLayerHarness {} }
    function test_actual_layer_layout_and_overlap() {
        sticks.visible=false
        const layer=createTemporaryObject(layerFactory,testCase)
        verify(layer)
        const loader=findChild(layer,"virtualJoystickLayer")
        tryVerify(function() { return loader.item !== null })
        const right=findChild(loader.item,"virtualJoystickRightPad")
        for (const sidebar of [0,350,550]) {
            layer.sidebar=sidebar
            for (const scale of [50,100,150]) {
                QGroundControl.settingsManager.appSettings.virtualJoystickSize.rawValue=scale
                const pos=right.mapToItem(layer,0,0)
                verify(right.width>0)
                verify(pos.x>=0 && pos.x+right.width<=layer.width)
                mousePress(right,right.width/2,right.height/2)
                mouseMove(right,right.width*0.8,right.height*0.3,10)
                verify(right.xAxis>0.45,"instrument consumed the right pad")
                mouseRelease(right,right.width/2,right.height/2)
            }
        }
        QGroundControl.settingsManager.appSettings.virtualJoystickSize.rawValue=100
    }
    function test_instrument_hit_test_regression() {
        sticks.visible=false
        const layer=createTemporaryObject(layerFactory,testCase)
        const loader=findChild(layer,"virtualJoystickLayer")
        tryVerify(function() { return loader.item !== null })
        const right=findChild(loader.item,"virtualJoystickRightPad")
        const fixedZ=loader.z
        // Reproduce the old stacking order: an ordinary instrument consumes input.
        loader.z=QGroundControl.zOrderTopMost+1
        mousePress(right,right.width/2,right.height/2)
        mouseMove(right,right.width*0.8,right.height/2,10)
        compare(right.touchActive,false); compare(right.xAxis,0)
        mouseRelease(right,right.width/2,right.height/2)
        // With the production stacking order the same pointer sequence reaches the pad.
        loader.z=fixedZ
        mousePress(right,right.width/2,right.height/2)
        mouseMove(right,right.width*0.8,right.height/2,10)
        verify(right.touchActive); verify(right.xAxis>0.45)
        mouseRelease(right,right.width/2,right.height/2)
    }
    function test_mouse_data() {
        return [ {tag:"desktop", w:760, h:150}, {tag:"phone", w:460, h:90},
                 {tag:"small50", w:760, h:75}, {tag:"large150", w:760, h:225} ]
    }
    function test_mouse(data) {
        sticks.width=data.w; sticks.height=data.h
        const p = pad("Right")
        mousePress(p,p.width*0.5,p.height*0.5)
        mouseMove(p,p.width*0.8,p.height*0.3,30)
        tryVerify(function() { return p.xAxis > 0.45 && p.yAxis > 0.3 })
        tryVerify(function() { return QGroundControl.testVehicle.axes.length===4 && QGroundControl.testVehicle.axes[0] > 0.45 })
        mouseRelease(p,p.width*0.8,p.height*0.3)
        tryCompare(p,"xAxis",0); tryCompare(p,"yAxis",0); compare(sticks.stickActive,false)
    }
    function test_two_fingers() {
        const left=pad("Left"), right=pad("Right")
        const touch=touchEvent(testCase)
        touch.press(0,left,left.width/2,left.height/2).commit()
        touch.stationary(0).press(1,right,right.width/2,right.height/2).commit()
        touch.move(0,left,left.width*0.2,left.height*0.8).move(1,right,right.width*0.8,right.height*0.2).commit()
        tryVerify(function() { return left.xAxis < -0.45 && right.xAxis > 0.45 && right.yAxis > 0.45 })
        tryVerify(function() { const a=QGroundControl.testVehicle.axes; return a.length===4 && a[0]>0.45 && a[2]<-0.45 })
        touch.release(1,right,right.width/2,right.height/2).stationary(0).commit()
        compare(sticks.stickActive,true); tryCompare(right,"xAxis",0)
        touch.release(0,left,left.width/2,left.height/2).commit()
        compare(sticks.stickActive,false)
    }
    function test_throttle_resize() {
        autoCenterThrottle=false
        const left=pad("Left")
        left.stickPositionY=left.height; left.calculateYAxis()
        mousePress(left,left.width/2,left.height*0.8)
        compare(left.yAxis,0)
        mouseMove(left,left.width/2,left.height*0.5,20)
        mouseRelease(left,left.width/2,left.height*0.5)
        const throttle=left.yAxis
        verify(throttle>0.2 && throttle<0.4)
        sticks.leftYAxisValue=throttle; sticks.height=100
        tryVerify(function() { return Math.abs(left.yAxis-throttle)<0.01 })
        const p=pad("Right"); mousePress(p,p.width/2,p.height/2); mouseMove(p,p.width*0.8,p.height*0.5,20)
        verify(p.xAxis>0.45); mouseRelease(p,p.width/2,p.height/2)
    }
    function test_reversed_mapping() {
        leftHandedMode=true
        const p=pad("Right")
        mousePress(p,p.width/2,p.height/2); mouseMove(p,p.width*0.8,p.height/2,20)
        tryVerify(function() { return QGroundControl.testVehicle.axes[2]>0.45 })
        mouseRelease(p,p.width/2,p.height/2)
    }
    function test_repeated_interruptions() {
        const right=pad("Right")
        for (let i=0; i<120; ++i) {
            sticks.height=[75,100,150,200][i%4]
            sticks.uiTotalWidth=i%2 ? 1000 : 0
            sticks.uiRealX=i%3 ? 120 : 420
            mousePress(right,right.width/2,right.height/2)
            mouseMove(right,right.width*0.8,right.height*0.3,2)
            verify(right.xAxis>0.45, "right pad rejected cycle "+i)
            if (i%3===0) {
                sticks.visible=false
                compare(right.xAxis,0)
                compare(sticks.stickActive,false)
            } else if (i%3===1) {
                right.enabled=false
                compare(right.xAxis,0)
                compare(sticks.stickActive,false)
            }
            mouseRelease(right,right.width/2,right.height/2)
            right.enabled=true; sticks.visible=true
            compare(right.xAxis,0)
        }
    }
    function test_hidden_throttle_resize_data() { return [{tag:"normal",reversed:false},{tag:"reversed",reversed:true}] }
    function test_hidden_throttle_resize(data) {
        autoCenterThrottle=false; leftHandedMode=data.reversed
        const throttle=pad(data.reversed ? "Right" : "Left")
        compare(throttle.yAxisReCenter,false)
        throttle.resize(0.3)
        sticks.leftYAxisValue=pad("Left").yAxis
        sticks.rightYAxisValue=pad("Right").yAxis
        sticks.visible=false; sticks.height=220; sticks.visible=true
        fuzzyCompare(throttle.yAxis,0.3,0.001)
        mousePress(throttle,throttle.width/2,throttle.height/2)
        mouseMove(throttle,throttle.width/2,throttle.height*0.45,20)
        verify(throttle.yAxis>0.34 && throttle.yAxis<0.37,"hidden resize changed held throttle")
        mouseRelease(throttle,throttle.width/2,throttle.height*0.45)
    }
    function test_disconnect_reconnect() {
        const right=pad("Right")
        mousePress(right,right.width/2,right.height/2)
        mouseMove(right,right.width*0.8,right.height/2,20)
        verify(right.xAxis>0.45)
        QGroundControl.multiVehicleManager.activeVehicle=null
        compare(sticks.stickActive,false); compare(right.xAxis,0)
        mouseRelease(right,right.width/2,right.height/2)
        QGroundControl.multiVehicleManager.activeVehicle=QGroundControl.testVehicle
        mousePress(right,right.width/2,right.height/2)
        mouseMove(right,right.width*0.8,right.height/2,20)
        verify(right.xAxis>0.45)
        mouseRelease(right,right.width/2,right.height/2)
    }
    function test_hidden_no_frames() {
        sticks.visible=false
        const count=QGroundControl.testVehicle.frames
        wait(100)
        compare(QGroundControl.testVehicle.frames,count)
    }
}
