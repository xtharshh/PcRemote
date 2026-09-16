import React, { useEffect, useState } from 'react';
import { View, Text, TextInput, Button, FlatList, TouchableOpacity, StyleSheet, Alert, ScrollView } from 'react-native';
import * as LocalAuthentication from 'expo-local-authentication';
import * as SecureStore from 'expo-secure-store';

// Phone PIN/biometric never leaves the phone. Only HMAC-style approval (X-PIN) goes to PC.
export default function App() {
  const [unlocked, setUnlocked] = useState(false); // phone-local gate
  const [ip, setIp] = useState('192.168.1.4');
  const [pin, setPin] = useState('1234');
  const [tab, setTab] = useState('home');
  const [out, setOut] = useState('');
  const [bri, setBri] = useState('50');
  const [pname, setPname] = useState('guest');
  const [pdata, setPdata] = useState('{"folders_deny":[],"settings_hide":"accounts;bluetooth","apps_deny":["regedit.exe"],"time_minutes":30}');
  const [drives, setDrives] = useState([]);
  const [folders, setFolders] = useState([]);
  const [sel, setSel] = useState(new Set());

  const base = () => `http://${ip.trim()}:5000`;
  const fetchWithTimeout = async (url, options = {}, timeoutMs = 8000) => {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const r = await fetch(url, { ...options, signal: controller.signal });
      return r;
    } finally {
      clearTimeout(id);
    }
  };
  const post = async (p, body) => {
    const r = await fetchWithTimeout(base() + p, { method: 'POST',
      headers: { 'X-PIN': pin, 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }, 10000);
    const j = await r.json();
    if (!r.ok) throw new Error(j.err || r.status);
    return j;
  };
  const get = async (p) => {
    const r = await fetchWithTimeout(base() + p, {}, 8000);
    return r.json();
  };

  useEffect(() => { (async () => {
    const sIp = await SecureStore.getItemAsync('pc_ip');
    const sPin = await SecureStore.getItemAsync('pc_pin');
    if (sIp) setIp(sIp);
    if (sPin) setPin(sPin);
    gate();
  })(); }, []);

  const gate = async () => {
    try {
      const has = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      if (has && enrolled) {
        const r = await LocalAuthentication.authenticateAsync({ promptMessage: 'Unlock PC Remote' });
        if (r.success) setUnlocked(true);
      } else setUnlocked(true); // no biometric -> fall back to PIN screen below
    } catch { setUnlocked(true); }
  };

  const saveCfg = async () => {
    await SecureStore.setItemAsync('pc_ip', ip.trim());
    await SecureStore.setItemAsync('pc_pin', pin.trim());
    Alert.alert('Saved', 'PC address + PIN stored on phone only.');
  };

  const run = async (fn) => { try { setOut(JSON.stringify(await fn(), null, 2)); } catch (e) { setOut('ERR: ' + e.message); } };
  const loadPick = async () => {
    const r = await get('/pick');
    setDrives(r.drives || []);
    if (r.drives?.[0]) browse(r.drives[1]?.root || r.drives[0].root);
  };
  const browse = async (path) => {
    const r = await get('/folders?path=' + encodeURIComponent(path));
    setFolders(r.folders || []);
    setSel(new Set());
  };
  const toggle = (full) => {
    const n = new Set(sel);
    n.has(full) ? n.delete(full) : n.add(full);
    setSel(n);
  };
  const addBlock = () => {
    try {
      const j = JSON.parse(pdata);
      j.folders_deny = [...new Set([...(j.folders_deny || []), ...sel])];
      setPdata(JSON.stringify(j, null, 2));
      setOut('added ' + sel.size + ' folder(s) to block list. Press Save profile.');
    } catch { setOut('Load profile first (bad JSON).'); }
  };

  if (!unlocked) return (
    <View style={s.c}><Text style={s.h}>PC Remote</Text>
      <Text style={s.t}>Phone PIN (stays on phone):</Text>
      <TextInput style={s.i} value={pin} onChangeText={setPin} secureTextEntry keyboardType="numeric" />
      <Button title="Unlock app" onPress={() => pin.trim().length >= 4 ? setUnlocked(true) : Alert.alert('PIN too short')} />
      <View style={{ height: 12 }} />
      <Button title="Use fingerprint" onPress={gate} />
    </View>
  );

  return (
    <ScrollView style={s.c}>
      <Text style={s.h}>PC Remote</Text>
      <View style={s.row}>
        <TextInput style={[s.i, { flex: 2 }]} value={ip} onChangeText={setIp} placeholder="PC IP e.g. 192.168.1.4" />
        <TextInput style={[s.i, { flex: 1 }]} value={pin} onChangeText={setPin} secureTextEntry placeholder="PIN" />
      </View>
      <Button title="Save on phone" onPress={saveCfg} />
      <View style={s.tabs}>
        {['home', 'bright', 'profiles', 'folders'].map(t => (
          <TouchableOpacity key={t} onPress={() => setTab(t)} style={[s.tab, tab === t && s.tabOn]}>
            <Text style={s.tt}>{t}</Text>
          </TouchableOpacity>
        ))}
      </View>
      {tab === 'home' && (<View>
        <Button title="LOCK NOW" color="#e53935" onPress={() => run(() => post('/lock'))} />
        <View style={{ height: 8 }} />
        <Button title="UNLOCK (approve)" color="#43a047" onPress={() => run(() => post('/unlock-approve'))} />
        <View style={{ height: 8 }} />
        <Button title="Status" onPress={() => run(() => get('/status'))} />
      </View>)}
      {tab === 'bright' && (<View>
        <TextInput style={s.i} value={bri} onChangeText={setBri} keyboardType="numeric" placeholder="0-100" />
        <Button title="Set brightness" onPress={() => run(() => post('/brightness', { level: +bri }))} />
        <View style={{ height: 8 }} />
        <Button title="Auto once" onPress={() => run(() => post('/auto-once'))} />
      </View>)}
      {tab === 'profiles' && (<View>
        <View style={s.row}>
          {[ 'admin', 'guest', 'kid' ].map(p => (
            <TouchableOpacity key={p} onPress={() => setPname(p)} style={[s.tab, pname === p && s.tabOn]}>
              <Text style={s.tt}>{p}</Text>
            </TouchableOpacity>
          ))}
        </View>
        <TextInput style={[s.i, { height: 140 }]} value={pdata} onChangeText={setPdata} multiline />
        <Button title="Load" onPress={() => run(async () => { const r = await post('/profile-get', { name: pname }); setPdata(JSON.stringify(r.data, null, 2)); return r; })} />
        <View style={{ height: 8 }} />
        <Button title="Save" onPress={() => run(() => post('/profile-save', { name: pname, data: JSON.parse(pdata) }))} />
        <View style={{ height: 8 }} />
        <Button title="Start profile" color="#43a047" onPress={() => run(() => post('/guest-start', { name: pname }))} />
        <View style={{ height: 8 }} />
        <Button title="Stop" color="#e53935" onPress={() => run(() => post('/guest-stop', { name: pname }))} />
      </View>)}
      {tab === 'folders' && (<View>
        <Button title="Scan laptop disks" onPress={() => run(async () => { const r = await get('/pick'); setDrives(r.drives || []); return r; })} />
        {drives.map(d => (
          <TouchableOpacity key={d.root} onPress={() => browse(d.root)}>
            <Text style={s.t}>{d.root} {d.label} ({d.free_gb}/{d.total_gb} GB)</Text>
          </TouchableOpacity>
        ))}
        <FlatList data={folders} keyExtractor={f => f.full} scrollEnabled={false}
          renderItem={({ item }) => (
            <TouchableOpacity onPress={() => toggle(item.full)}>
              <Text style={[s.t, sel.has(item.full) && { color: '#4caf50' }]}>
                {sel.has(item.full) ? '[x] ' : '[ ] '}{item.name}
              </Text>
            </TouchableOpacity>
          )} />
        <Button title={`+ Add ${sel.size} to block list`} onPress={addBlock} />
      </View>)}
      <Text style={s.out}>{out}</Text>
    </ScrollView>
  );
}
const s = StyleSheet.create({
  c: { flex: 1, backgroundColor: '#111', padding: 14 },
  h: { color: '#fff', fontSize: 22, fontWeight: 'bold', marginVertical: 8 },
  t: { color: '#fff', marginVertical: 4 },
  i: { backgroundColor: '#222', color: '#fff', padding: 12, borderRadius: 10, marginVertical: 6 },
  row: { flexDirection: 'row', gap: 8 },
  tabs: { flexDirection: 'row', gap: 6, marginVertical: 8 },
  tab: { flex: 1, backgroundColor: '#333', padding: 10, borderRadius: 10, alignItems: 'center' },
  tabOn: { backgroundColor: '#1e88e5' },
  tt: { color: '#fff' },
  out: { color: '#0f0', fontSize: 12, marginTop: 10 },
});
