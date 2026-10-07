#!/usr/bin/env python3
import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from zoneinfo import ZoneInfo
spec=importlib.util.spec_from_file_location("dj",Path(__file__).parent/"desk-dj/desk-dj-linux.py")
dj=importlib.util.module_from_spec(spec);spec.loader.exec_module(dj)
class FakeDesktop:
    def __init__(self): self.calls=[]
    def set_volume(self,v): self.calls.append(("volume",v));return str(v)
    def play(self,u): self.calls.append(("play",u))
    def pause(self): self.calls.append(("pause",))
    def status(self): return {"spotify_up":True,"playing":True}
class Tests(unittest.TestCase):
    def setUp(self):
        self.config=json.loads((Path(__file__).parent/"desk-dj/playlist-config.json").read_text())
        self.now=dt.datetime(2026,10,7,10,tzinfo=ZoneInfo("America/Chicago"))
    def test_anti_repeat(self):
        c={"sources":[{"uri":"A","weight":2},{"uri":"B","weight":1}],"personal_slots":[{"uri":"A","weight":3}]}
        self.assertEqual(dj.choose(c,"A",self.now)["uri"],"B")
        c["sources"]=[];self.assertEqual(dj.choose(c,"A",self.now)["uri"],"A")
        c["personal_slots"]=[]
        with self.assertRaises(ValueError):dj.choose(c,"",self.now)
    def test_volume(self):
        for v,w in [(None,.25),("invalid",.25),(-1,0),(2,1),(0,0)]:
            self.assertEqual(dj.volume_target({"playback_volume":v}),w)
    def test_window(self):
        for h,m,w in [(8,59,False),(9,0,True),(18,59,True),(19,0,False)]:
            self.assertEqual(dj.in_window(self.config,self.now.replace(hour=h,minute=m)),w)
    def test_play_and_state(self):
        with tempfile.TemporaryDirectory() as t:
            state=Path(t)/"state.json"; desktop=FakeDesktop()
            first=dj.execute("start",self.config,state,desktop,self.now)
            second=dj.execute("rotate",self.config,state,desktop,self.now)
            self.assertNotEqual(first["uri"],second["uri"])
            self.assertEqual(desktop.calls[0],("volume",.25))
            self.assertEqual(json.loads(state.read_text())["uri"],second["uri"])
            desktop.calls=[]
            dj.execute("rotate",self.config,state,desktop,self.now.replace(hour=20))
            self.assertEqual(desktop.calls,[])
            dj.execute("start",self.config,state,desktop,self.now.replace(hour=20))
            self.assertEqual(desktop.calls[0],("volume",.25))
    def test_failure_keeps_state(self):
        with tempfile.TemporaryDirectory() as t:
            state=Path(t)/"state.json";state.write_text('{"uri":"previous"}')
            desktop=FakeDesktop()
            def fail(u):raise RuntimeError("not playing")
            desktop.play=fail
            with self.assertRaises(RuntimeError):dj.execute("start",self.config,state,desktop,self.now)
            self.assertEqual(json.loads(state.read_text())["uri"],"previous")
if __name__=="__main__":unittest.main()
