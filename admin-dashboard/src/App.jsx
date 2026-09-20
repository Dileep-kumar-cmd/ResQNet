import React, { useState, useEffect, useRef } from 'react';
import { 
  Shield, 
  Activity, 
  Radio, 
  AlertTriangle, 
  Home, 
  Users, 
  RefreshCw, 
  Search, 
  Plus, 
  CheckCircle2, 
  Clock, 
  MapPin, 
  Box, 
  ExternalLink, 
  Layers, 
  Wifi, 
  Database,
  Truck,
  Droplets,
  HeartPulse,
  Zap,
  Filter,
  X,
  Volume2,
  VolumeX,
  BellRing
} from 'lucide-react';

const API_BASE = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
const WS_BASE = import.meta.env.VITE_WS_URL || API_BASE.replace(/^http/, 'ws');

export default function App() {
  // Navigation active tab: 'overview' | 'shelters' | 'sos' | 'mesh' | 'resources'
  const [activeTab, setActiveTab] = useState('overview');

  const [serverStatus, setServerStatus] = useState('CHECKING');
  const [lastCheck, setLastCheck] = useState(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Core Data
  const [shelters, setShelters] = useState([]);
  const [sosLogs, setSosLogs] = useState([]);
  const [conflicts, setConflicts] = useState([]);

  // Search and Filters
  const [shelterSearch, setShelterSearch] = useState('');
  const [shelterHazardFilter, setShelterHazardFilter] = useState('ALL');
  const [sosStatusFilter, setSosStatusFilter] = useState('ALL');
  const [sosSearch, setSosSearch] = useState('');

  // Modals
  const [isAddShelterOpen, setIsAddShelterOpen] = useState(false);
  const [isAddSosOpen, setIsAddSosOpen] = useState(false);
  const [newShelterForm, setNewShelterForm] = useState({
    name: '',
    capacity: 200,
    current_occupancy: 25,
    hazard_rating: 0,
    latitude: 37.7749,
    longitude: -122.4194
  });
  // Emergency Alert & Audio Tone State
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [activeEmergencyAlert, setActiveEmergencyAlert] = useState(null);
  const knownSosIdsRef = useRef(new Set());
  const audioCtxRef = useRef(null);

  // Synthesize short deep emergency sound using HTML5 Web Audio API
  const playEmergencyAudio = () => {
    if (!audioEnabled) return;
    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return;
      
      const ctx = audioCtxRef.current || new AudioContextClass();
      audioCtxRef.current = ctx;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }

      const now = ctx.currentTime;
      const bursts = 2;
      const burstDuration = 0.35;
      const pauseDuration = 0.12;
      const fundamentalFreq = 180; // short deep emergency fundamental

      for (let b = 0; b < bursts; b++) {
        const startTime = now + b * (burstDuration + pauseDuration);
        const stopTime = startTime + burstDuration;

        // Rich low-frequency oscillator blend (fundamental 180Hz + sub-bass 90Hz)
        const osc1 = ctx.createOscillator();
        const osc2 = ctx.createOscillator();
        const filter = ctx.createBiquadFilter();
        const gain = ctx.createGain();

        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(360, startTime);

        osc1.type = 'sawtooth';
        osc1.frequency.setValueAtTime(fundamentalFreq, startTime);
        osc1.frequency.exponentialRampToValueAtTime(fundamentalFreq * 0.85, stopTime);

        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(fundamentalFreq / 2, startTime);

        // Amplitude envelope (fast attack, sustained resonance, decay)
        gain.gain.setValueAtTime(0.001, startTime);
        gain.gain.linearRampToValueAtTime(0.7, startTime + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.001, stopTime);

        osc1.connect(filter);
        osc2.connect(filter);
        filter.connect(gain);
        gain.connect(ctx.destination);

        osc1.start(startTime);
        osc2.start(startTime);
        osc1.stop(stopTime);
        osc2.stop(stopTime);
      }
    } catch (err) {
      console.warn('[AUDIO_ERROR] Emergency sound playback failed:', err);
    }
  };

  const [newSosForm, setNewSosForm] = useState({
    user_id: 'usr_mobile_field_' + Math.floor(100 + Math.random() * 900),
    latitude: 37.7790,
    longitude: -122.4120,
    status: 'QUEUED'
  });

  const fetchAdminData = async () => {
    setIsRefreshing(true);
    try {
      // 1. Health check
      const resHealth = await fetch(`${API_BASE}/api/v1/health`);
      if (resHealth.ok) {
        setServerStatus('ONLINE');
      } else {
        setServerStatus('DEGRADED');
      }

      // 2. Shelters
      const resShelters = await fetch(`${API_BASE}/api/v1/admin/shelters`);
      if (resShelters.ok) {
        const data = await resShelters.json();
        setShelters(data);
      }

      // 3. SOS Logs
      const resSos = await fetch(`${API_BASE}/api/v1/admin/sos_logs`);
      if (resSos.ok) {
        const data = await resSos.json();
        setSosLogs(data);

        // Check for new queued SOS logs to trigger deep emergency sound
        if (knownSosIdsRef.current.size > 0) {
          const incomingNew = data.find(
            s => s.status === 'QUEUED' && !knownSosIdsRef.current.has(s.id)
          );
          if (incomingNew) {
            setActiveEmergencyAlert(incomingNew);
            playEmergencyAudio();
          }
        }
        data.forEach(s => knownSosIdsRef.current.add(s.id));
      }

      // 4. CRDT Conflict Audits
      const resConflicts = await fetch(`${API_BASE}/api/v1/admin/conflicts_audit`);
      if (resConflicts.ok) {
        const data = await resConflicts.json();
        setConflicts(data);
      }
    } catch (e) {
      setServerStatus('OFFLINE_OR_UNREACHABLE');
    } finally {
      setIsRefreshing(false);
      setLastCheck(new Date().toLocaleTimeString());
    }
  };

  // Real-time WebSocket connection to backend alerts endpoint
  useEffect(() => {
    let ws;
    let reconnectTimer;

    const connectAlertsWebSocket = () => {
      try {
        ws = new WebSocket(`${WS_BASE}/api/v1/alerts/ws`);
        ws.onopen = () => {
          console.log('[ALERTS_WS] Connected to Emergency Broadcast Stream');
        };
        ws.onmessage = (event) => {
          try {
            const packet = JSON.parse(event.data);
            if (packet.type === 'EMERGENCY_SOS_ALERT' && packet.data) {
              console.warn('[ALERTS_WS] Emergency SOS received:', packet.data);
              setActiveEmergencyAlert(packet.data);
              playEmergencyAudio();
              fetchAdminData();
            }
          } catch (e) {}
        };
        ws.onclose = () => {
          reconnectTimer = setTimeout(connectAlertsWebSocket, 4000);
        };
        ws.onerror = () => {
          ws.close();
        };
      } catch (err) {
        reconnectTimer = setTimeout(connectAlertsWebSocket, 4000);
      }
    };

    connectAlertsWebSocket();
    return () => {
      if (ws) ws.close();
      clearTimeout(reconnectTimer);
    };
  }, [audioEnabled]);

  useEffect(() => {
    fetchAdminData();
    const interval = setInterval(fetchAdminData, 4000);
    return () => clearInterval(interval);
  }, []);

  // Shelter Occupancy update
  const handleUpdateOccupancy = async (shelterId, newOccupancy) => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/admin/shelters/${shelterId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncodeSafe({ current_occupancy: Math.max(0, newOccupancy) })
      });
      if (res.ok) {
        fetchAdminData();
      }
    } catch (e) {
      console.error('Failed to update occupancy', e);
    }
  };

  // SOS status update
  const handleUpdateSosStatus = async (sosId, newStatus) => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/admin/sos_logs/${sosId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncodeSafe({ status: newStatus })
      });
      if (res.ok) {
        fetchAdminData();
      }
    } catch (e) {
      console.error('Failed to update SOS status', e);
    }
  };

  // Add new shelter
  const handleCreateShelter = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/api/v1/admin/shelters`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncodeSafe(newShelterForm)
      });
      if (res.ok) {
        setIsAddShelterOpen(false);
        setNewShelterForm({
          name: '',
          capacity: 200,
          current_occupancy: 25,
          hazard_rating: 0,
          latitude: 37.7749,
          longitude: -122.4194
        });
        fetchAdminData();
      }
    } catch (err) {
      console.error('Failed to create shelter', err);
    }
  };

  // Create SOS signal
  const handleCreateSos = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`${API_BASE}/api/v1/admin/sos_logs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncodeSafe({
          ...newSosForm,
          relay_path: ['node_admin_dispatch', 'gateway_hq']
        })
      });
      if (res.ok) {
        setIsAddSosOpen(false);
        fetchAdminData();
      }
    } catch (err) {
      console.error('Failed to create SOS', err);
    }
  };

  function jsonEncodeSafe(obj) {
    return JSON.stringify(obj);
  }

  // Derived Stats
  const totalOccupancy = shelters.reduce((acc, s) => acc + (s.current_occupancy || 0), 0);
  const totalCapacity = shelters.reduce((acc, s) => acc + (s.capacity || 0), 0);
  const capacityPercent = totalCapacity > 0 ? ((totalOccupancy / totalCapacity) * 100).toFixed(1) : '0';

  const queuedSosCount = sosLogs.filter(s => s.status === 'QUEUED').length;
  const dispatchedSosCount = sosLogs.filter(s => s.status === 'DISPATCHED').length;
  const resolvedSosCount = sosLogs.filter(s => s.status === 'RESOLVED').length;

  // Filtered Shelters
  const filteredShelters = shelters.filter(s => {
    const matchesSearch = s.name.toLowerCase().includes(shelterSearch.toLowerCase()) || s.id.toLowerCase().includes(shelterSearch.toLowerCase());
    if (shelterHazardFilter === 'LOW') return matchesSearch && s.hazard_rating <= 1;
    if (shelterHazardFilter === 'MODERATE') return matchesSearch && s.hazard_rating === 2;
    if (shelterHazardFilter === 'HIGH') return matchesSearch && s.hazard_rating >= 3;
    return matchesSearch;
  });

  // Filtered SOS
  const filteredSos = sosLogs.filter(sos => {
    const matchesSearch = sos.id.toLowerCase().includes(sosSearch.toLowerCase()) || (sos.user_id && sos.user_id.toLowerCase().includes(sosSearch.toLowerCase()));
    if (sosStatusFilter !== 'ALL') {
      return matchesSearch && sos.status === sosStatusFilter;
    }
    return matchesSearch;
  });

  // Simulated Mesh Topology Nodes
  const meshNodes = [
    { id: 'node_gateway_hq', name: 'HQ Command Gateway', role: 'Server Relay', rssi: -42, battery: 100, peers: 4, status: 'ONLINE' },
    { id: 'node_alpha_civic', name: 'Civic Shelter Beacon', role: 'Anchor Node', rssi: -58, battery: 94, peers: 3, status: 'ONLINE' },
    { id: 'node_beta_highschool', name: 'North Hill Relay', role: 'Anchor Node', rssi: -65, battery: 88, peers: 4, status: 'ONLINE' },
    { id: 'node_patrol_lead', name: 'Rescue Patrol Unit 1', role: 'Mobile Mesh Node', rssi: -72, battery: 76, peers: 2, status: 'ONLINE' },
    { id: 'node_medic_triage', name: 'Field Medic Unit 4', role: 'Mobile Mesh Node', rssi: -79, battery: 61, peers: 2, status: 'ONLINE' },
  ];

  return (
    <div className="dashboard-container">
      {/* Sidebar Navigation */}
      <aside className="sidebar">
        <div className="brand-header">
          <div className="brand-logo">R</div>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: 700, letterSpacing: '-0.02em' }}>ResQNet HQ</h2>
            <p style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Disaster Command Portal</p>
          </div>
        </div>

        <nav style={{ flex: 1 }}>
          <div 
            className={`nav-item ${activeTab === 'overview' ? 'active' : ''}`} 
            onClick={() => setActiveTab('overview')}
          >
            <Activity size={18} /> 
            <span>Overview</span>
          </div>

          <div 
            className={`nav-item ${activeTab === 'shelters' ? 'active' : ''}`} 
            onClick={() => setActiveTab('shelters')}
          >
            <Home size={18} /> 
            <span>Shelters</span>
            <span className="nav-badge nav-badge-gray">{shelters.length}</span>
          </div>

          <div 
            className={`nav-item ${activeTab === 'sos' ? 'active' : ''}`} 
            onClick={() => setActiveTab('sos')}
          >
            <AlertTriangle size={18} /> 
            <span>Emergency SOS</span>
            {queuedSosCount > 0 ? (
              <span className="nav-badge nav-badge-red">{queuedSosCount}</span>
            ) : (
              <span className="nav-badge nav-badge-gray">{sosLogs.length}</span>
            )}
          </div>

          <div 
            className={`nav-item ${activeTab === 'mesh' ? 'active' : ''}`} 
            onClick={() => setActiveTab('mesh')}
          >
            <Radio size={18} /> 
            <span>Mesh Topology</span>
          </div>

          <div 
            className={`nav-item ${activeTab === 'resources' ? 'active' : ''}`} 
            onClick={() => setActiveTab('resources')}
          >
            <Box size={18} /> 
            <span>Logistics & AI</span>
          </div>
        </nav>

        <div style={{ padding: '16px 8px', borderTop: '1px solid var(--border-card)', fontSize: '12px', color: 'var(--text-secondary)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--accent-green)', fontWeight: 600, marginBottom: '4px' }}>
            <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--accent-green)' }} />
            CRDT Engine Active
          </div>
          <div>LWW Automatic Resolution</div>
          <div style={{ marginTop: '6px', color: 'var(--text-muted)' }}>v1.0.0 Production</div>
        </div>
      </aside>

      {/* Main Content Workspace */}
      <main className="main-content">
        {/* Top Header Bar */}
        <div className="top-bar">
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <h1 style={{ fontSize: '24px', fontWeight: 700 }}>
                {activeTab === 'overview' && 'Command Center Overview'}
                {activeTab === 'shelters' && 'Regional Shelter Management'}
                {activeTab === 'sos' && 'Emergency SOS Dispatch Console'}
                {activeTab === 'mesh' && 'Offline Mesh Network Topology & Audits'}
                {activeTab === 'resources' && 'Logistics & AI Shortage Forecaster'}
              </h1>
            </div>
            <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '2px' }}>
              {activeTab === 'overview' && 'Real-time synchronization metrics across mobile responders and local shelters'}
              {activeTab === 'shelters' && 'Monitor occupancy, hazard levels, equipment stock, and adjust shelter capacity'}
              {activeTab === 'sos' && 'Live distress beacons routed via offline peer-to-peer mobile mesh relays'}
              {activeTab === 'mesh' && 'Inspect ad-hoc hop routes, packet deduplication, and CRDT conflict audits'}
              {activeTab === 'resources' && 'On-device predictive AI depletion forecasts for water, meals, and medical supplies'}
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <button 
              className="btn btn-secondary"
              onClick={() => {
                const nextState = !audioEnabled;
                setAudioEnabled(nextState);
                if (nextState) playEmergencyAudio();
              }}
              style={{
                borderColor: audioEnabled ? 'var(--accent-red)' : 'var(--border-card)',
                color: audioEnabled ? '#f87171' : 'var(--text-secondary)'
              }}
              title={audioEnabled ? "Audio Alerts Enabled (Click to Mute)" : "Audio Alerts Muted (Click to Enable)"}
            >
              {audioEnabled ? <Volume2 size={14} /> : <VolumeX size={14} />}
              {audioEnabled ? 'Audio Alert: ON' : 'Audio Alert: OFF'}
            </button>

            <button 
              className="btn btn-secondary"
              onClick={playEmergencyAudio}
              title="Test Short Deep Emergency Audio Tone"
            >
              <BellRing size={14} /> Test Tone
            </button>

            <button 
              className="btn btn-secondary"
              onClick={fetchAdminData}
              disabled={isRefreshing}
            >
              <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} /> 
              {isRefreshing ? 'Syncing...' : 'Poll Server'}
            </button>

            <span className={`status-badge ${serverStatus === 'ONLINE' ? 'status-online' : 'status-offline'}`}>
              <span style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: serverStatus === 'ONLINE' ? 'var(--accent-green)' : 'var(--accent-red)'
              }} />
              FastAPI: {serverStatus} {lastCheck && `(${lastCheck})`}
            </span>
          </div>
        </div>

        {/* Emergency Incoming SOS Alert Banner */}
        {activeEmergencyAlert && (
          <div style={{
            background: 'linear-gradient(90deg, rgba(239, 68, 68, 0.28), rgba(185, 28, 28, 0.45))',
            border: '2px solid var(--accent-red)',
            borderRadius: '12px',
            padding: '16px 20px',
            marginBottom: '20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            boxShadow: '0 0 30px rgba(239, 68, 68, 0.4)',
            transition: 'all 0.3s ease'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{
                background: 'var(--accent-red)',
                color: '#fff',
                padding: '12px',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 0 15px rgba(239, 68, 68, 0.8)'
              }}>
                <AlertTriangle size={26} />
              </div>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <span style={{ color: '#fca5a5', fontWeight: 800, fontSize: '15px', letterSpacing: '0.04em' }}>
                    🚨 CRITICAL EMERGENCY SOS SIGNAL RECEIVED
                  </span>
                  <span className="status-badge" style={{ background: '#7f1d1d', color: '#fecaca', fontSize: '11px', fontWeight: 700 }}>
                    {activeEmergencyAlert.status || 'QUEUED'}
                  </span>
                </div>
                <div style={{ color: '#f1f5f9', fontSize: '13px', marginTop: '6px' }}>
                  <strong>Victim / Node:</strong> <code style={{ color: '#67e8f9' }}>{activeEmergencyAlert.user_id || activeEmergencyAlert.id}</code> &bull; 
                  <strong> GPS:</strong> {Number(activeEmergencyAlert.latitude || 37.7749).toFixed(4)}, {Number(activeEmergencyAlert.longitude || -122.4194).toFixed(4)} &bull; 
                  <strong> Details:</strong> {activeEmergencyAlert.medical_note || 'Emergency medical & rescue assistance requested'}
                </div>
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <button 
                className="btn btn-secondary"
                style={{ borderColor: 'var(--accent-red)', color: '#fecaca' }}
                onClick={playEmergencyAudio}
                title="Replay Short Deep Emergency Sound"
              >
                <Volume2 size={15} /> Replay Alert Sound
              </button>
              <button 
                className="btn"
                style={{ background: 'var(--accent-red)', color: '#fff', fontWeight: 700 }}
                onClick={() => {
                  handleUpdateSosStatus(activeEmergencyAlert.id, 'DISPATCHED');
                  setActiveTab('sos');
                  setActiveEmergencyAlert(null);
                }}
              >
                Dispatch Rescue Team
              </button>
              <button 
                className="btn btn-secondary"
                onClick={() => setActiveEmergencyAlert(null)}
                title="Dismiss Alert"
              >
                <X size={15} />
              </button>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 1: OVERVIEW TAB */}
        {/* ========================================================================= */}
        {activeTab === 'overview' && (
          <div>
            {/* Quick Stats Grid */}
            <div className="stats-grid">
              <div className="stat-card" onClick={() => setActiveTab('shelters')} style={{ cursor: 'pointer' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>ACTIVE SHELTERS</span>
                  <Home size={16} color="var(--accent-blue)" />
                </div>
                <div className="stat-value">{shelters.length}</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-green)' }}>Regionally Synced</div>
              </div>

              <div className="stat-card" onClick={() => setActiveTab('shelters')} style={{ cursor: 'pointer' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>OCCUPANCY / CAPACITY</span>
                  <Users size={16} color="#f59e0b" />
                </div>
                <div className="stat-value">{totalOccupancy} / {totalCapacity}</div>
                <div className="progress-bar-bg">
                  <div 
                    className="progress-bar-fill" 
                    style={{ 
                      width: `${Math.min(100, Number(capacityPercent))}%`,
                      background: Number(capacityPercent) > 85 ? 'var(--accent-red)' : Number(capacityPercent) > 60 ? 'var(--accent-yellow)' : 'var(--accent-green)'
                    }} 
                  />
                </div>
                <div style={{ fontSize: '12px', color: '#f59e0b', marginTop: '6px' }}>{capacityPercent}% Total Utilized</div>
              </div>

              <div className="stat-card" onClick={() => setActiveTab('sos')} style={{ cursor: 'pointer' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>CRITICAL SOS SIGNALS</span>
                  <AlertTriangle size={16} color="var(--accent-red)" />
                </div>
                <div className="stat-value" style={{ color: queuedSosCount > 0 ? '#ef4444' : '#fff' }}>
                  {queuedSosCount} <span style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 400 }}>queued</span>
                </div>
                <div style={{ fontSize: '12px', color: queuedSosCount > 0 ? 'var(--accent-red)' : 'var(--accent-green)' }}>
                  {queuedSosCount > 0 ? 'Immediate action required' : 'All distress alerts addressed'}
                </div>
              </div>

              <div className="stat-card" onClick={() => setActiveTab('mesh')} style={{ cursor: 'pointer' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>MESH ACTIVE NODES</span>
                  <Radio size={16} color="var(--accent-indigo)" />
                </div>
                <div className="stat-value">{meshNodes.length}</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-cyan)' }}>Zero-Cellular Relay</div>
              </div>
            </div>

            {/* Overview Quick Actions Bar */}
            <div style={{ display: 'flex', gap: '12px', marginBottom: '24px' }}>
              <button className="btn btn-primary" onClick={() => setIsAddShelterOpen(true)}>
                <Plus size={16} /> Add Regional Shelter
              </button>
              <button className="btn btn-danger" onClick={() => setIsAddSosOpen(true)}>
                <AlertTriangle size={16} /> Simulate Distress SOS
              </button>
              <button className="btn btn-secondary" onClick={() => setActiveTab('resources')}>
                <Box size={16} /> View AI Depletion Forecasts
              </button>
            </div>

            {/* Two Column Layout: Urgent SOS & Shelters Near Capacity */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '24px' }}>
              {/* Urgent SOS Quick Card */}
              <div className="data-table-card">
                <div className="table-header">
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: 600 }}>Active Distress Queue</h3>
                    <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Prioritized emergency dispatches</p>
                  </div>
                  <button className="btn btn-secondary btn-sm" onClick={() => setActiveTab('sos')}>
                    View All ({sosLogs.length})
                  </button>
                </div>
                {sosLogs.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                    No SOS signals recorded yet.
                  </div>
                ) : (
                  <table>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>User</th>
                        <th>Status</th>
                        <th>Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {sosLogs.slice(0, 4).map(sos => (
                        <tr key={sos.id}>
                          <td style={{ fontFamily: 'monospace', fontWeight: 700, color: '#f87171' }}>{sos.id}</td>
                          <td>{sos.user_id}</td>
                          <td>
                            <span className={`badge ${sos.status === 'QUEUED' ? 'badge-urgent' : sos.status === 'DISPATCHED' ? 'badge-warning' : 'badge-success'}`}>
                              {sos.status}
                            </span>
                          </td>
                          <td>
                            {sos.status === 'QUEUED' && (
                              <button 
                                className="btn btn-primary btn-sm"
                                onClick={() => handleUpdateSosStatus(sos.id, 'DISPATCHED')}
                              >
                                Dispatch
                              </button>
                            )}
                            {sos.status === 'DISPATCHED' && (
                              <button 
                                className="btn btn-success btn-sm"
                                onClick={() => handleUpdateSosStatus(sos.id, 'RESOLVED')}
                              >
                                Resolve
                              </button>
                            )}
                            {sos.status === 'RESOLVED' && (
                              <span style={{ fontSize: '12px', color: 'var(--accent-green)' }}>Completed</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>

              {/* Shelters Quick Status */}
              <div className="data-table-card">
                <div className="table-header">
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: 600 }}>Regional Shelter Status</h3>
                    <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Capacity and hazard snapshot</p>
                  </div>
                  <button className="btn btn-secondary btn-sm" onClick={() => setActiveTab('shelters')}>
                    Manage ({shelters.length})
                  </button>
                </div>
                <table>
                  <thead>
                    <tr>
                      <th>Shelter Name</th>
                      <th>Occupancy</th>
                      <th>Load</th>
                      <th>Hazard</th>
                    </tr>
                  </thead>
                  <tbody>
                    {shelters.slice(0, 4).map(s => {
                      const occ = s.current_occupancy || 0;
                      const cap = s.capacity || 100;
                      const pct = Math.round((occ / cap) * 100);
                      return (
                        <tr key={s.id}>
                          <td style={{ fontWeight: 600 }}>{s.name}</td>
                          <td>{occ} / {cap}</td>
                          <td style={{ width: '120px' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <span style={{ fontSize: '12px', minWidth: '35px' }}>{pct}%</span>
                              <div className="progress-bar-bg" style={{ flex: 1, marginTop: 0 }}>
                                <div 
                                  className="progress-bar-fill"
                                  style={{
                                    width: `${Math.min(100, pct)}%`,
                                    background: pct > 85 ? 'var(--accent-red)' : pct > 60 ? 'var(--accent-yellow)' : 'var(--accent-green)'
                                  }}
                                />
                              </div>
                            </div>
                          </td>
                          <td>
                            <span className={`badge ${s.hazard_rating >= 2 ? 'badge-urgent' : s.hazard_rating === 1 ? 'badge-warning' : 'badge-success'}`}>
                              Lvl {s.hazard_rating}
                            </span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 2: SHELTERS TAB */}
        {/* ========================================================================= */}
        {activeTab === 'shelters' && (
          <div>
            <div className="data-table-card">
              <div className="table-header">
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600 }}>Shelter Fleet & Live Capacity</h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>CRDT Last-Write-Wins synchronized regional evacuation hubs</p>
                </div>
                <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                  <input 
                    type="text" 
                    className="search-input" 
                    placeholder="Search shelters by name..." 
                    value={shelterSearch}
                    onChange={(e) => setShelterSearch(e.target.value)}
                  />
                  <select 
                    className="filter-select"
                    value={shelterHazardFilter}
                    onChange={(e) => setShelterHazardFilter(e.target.value)}
                  >
                    <option value="ALL">All Hazard Levels</option>
                    <option value="LOW">Low Hazard (Lvl 0-1)</option>
                    <option value="MODERATE">Moderate Hazard (Lvl 2)</option>
                    <option value="HIGH">High Risk (Lvl 3+)</option>
                  </select>
                  <button className="btn btn-primary btn-sm" onClick={() => setIsAddShelterOpen(true)}>
                    <Plus size={14} /> Add Shelter
                  </button>
                </div>
              </div>

              <table>
                <thead>
                  <tr>
                    <th>Shelter ID</th>
                    <th>Shelter Name</th>
                    <th>GPS Coords</th>
                    <th>Occupancy / Cap</th>
                    <th>Utilization</th>
                    <th>Hazard</th>
                    <th>Stock / Supplies</th>
                    <th>Quick Adjust</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredShelters.map(s => {
                    const occ = s.current_occupancy || 0;
                    const cap = s.capacity || 100;
                    const percent = Math.round((occ / cap) * 100);
                    const equip = s.equipment_json || {};

                    return (
                      <tr key={s.id}>
                        <td style={{ fontFamily: 'monospace', fontWeight: 600, color: 'var(--text-secondary)' }}>{s.id}</td>
                        <td style={{ fontWeight: 600 }}>{s.name}</td>
                        <td>
                          <a 
                            href={`https://www.google.com/maps?q=${s.latitude},${s.longitude}`} 
                            target="_blank" 
                            rel="noreferrer"
                            style={{ color: 'var(--accent-blue)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px' }}
                          >
                            <MapPin size={12} /> {s.latitude.toFixed(4)}, {s.longitude.toFixed(4)}
                          </a>
                        </td>
                        <td>{occ} / {cap}</td>
                        <td style={{ width: '140px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <span style={{ fontSize: '12px', minWidth: '35px' }}>{percent}%</span>
                            <div className="progress-bar-bg" style={{ flex: 1, marginTop: 0 }}>
                              <div 
                                className="progress-bar-fill" 
                                style={{ 
                                  width: `${Math.min(100, percent)}%`,
                                  background: percent > 85 ? 'var(--accent-red)' : percent > 60 ? 'var(--accent-yellow)' : 'var(--accent-green)'
                                }} 
                              />
                            </div>
                          </div>
                        </td>
                        <td>
                          <span className={`badge ${s.hazard_rating >= 2 ? 'badge-urgent' : s.hazard_rating === 1 ? 'badge-warning' : 'badge-success'}`}>
                            Hazard Lvl {s.hazard_rating}
                          </span>
                        </td>
                        <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                          <div>💧 {equip.clean_water_liters || 2500}L Water</div>
                          <div>🩹 {equip.first_aid_kits || 25} Med Kits</div>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: '4px' }}>
                            <button 
                              className="btn btn-secondary btn-sm"
                              onClick={() => handleUpdateOccupancy(s.id, occ - 10)}
                              title="Decrease occupancy by 10"
                            >
                              -10
                            </button>
                            <button 
                              className="btn btn-secondary btn-sm"
                              onClick={() => handleUpdateOccupancy(s.id, occ + 10)}
                              title="Increase occupancy by 10"
                            >
                              +10
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 3: EMERGENCY SOS TAB */}
        {/* ========================================================================= */}
        {activeTab === 'sos' && (
          <div>
            <div className="data-table-card">
              <div className="table-header">
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600 }}>Emergency Distress Radar</h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Live triage & rescue dispatch operations</p>
                </div>
                <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                  <input 
                    type="text" 
                    className="search-input" 
                    placeholder="Search SOS ID / User..." 
                    value={sosSearch}
                    onChange={(e) => setSosSearch(e.target.value)}
                  />
                  <button className="btn btn-danger btn-sm" onClick={() => setIsAddSosOpen(true)}>
                    <Plus size={14} /> Send SOS Beacon
                  </button>
                </div>
              </div>

              {/* Status Filter Pills */}
              <div className="filter-pills" style={{ marginBottom: '20px' }}>
                <div 
                  className={`filter-pill ${sosStatusFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setSosStatusFilter('ALL')}
                >
                  All Signals ({sosLogs.length})
                </div>
                <div 
                  className={`filter-pill ${sosStatusFilter === 'QUEUED' ? 'active' : ''}`}
                  onClick={() => setSosStatusFilter('QUEUED')}
                >
                  Queued / Critical ({queuedSosCount})
                </div>
                <div 
                  className={`filter-pill ${sosStatusFilter === 'DISPATCHED' ? 'active' : ''}`}
                  onClick={() => setSosStatusFilter('DISPATCHED')}
                >
                  Dispatched Teams ({dispatchedSosCount})
                </div>
                <div 
                  className={`filter-pill ${sosStatusFilter === 'RESOLVED' ? 'active' : ''}`}
                  onClick={() => setSosStatusFilter('RESOLVED')}
                >
                  Resolved ({resolvedSosCount})
                </div>
              </div>

              <table>
                <thead>
                  <tr>
                    <th>Signal ID</th>
                    <th>User / Originator</th>
                    <th>GPS Coordinates</th>
                    <th>Relay Hops</th>
                    <th>Time Queued</th>
                    <th>Status</th>
                    <th>Dispatch Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredSos.map(sos => {
                    const latStr = typeof sos.latitude === 'number' ? sos.latitude.toFixed(4) : sos.latitude;
                    const lonStr = typeof sos.longitude === 'number' ? sos.longitude.toFixed(4) : sos.longitude;
                    const relayPath = Array.isArray(sos.relay_path) ? sos.relay_path : [];
                    const timeFormatted = sos.timestamp ? new Date(sos.timestamp).toLocaleTimeString() : 'Just now';

                    return (
                      <tr key={sos.id}>
                        <td style={{ fontFamily: 'monospace', fontWeight: 700, color: '#f87171' }}>{sos.id}</td>
                        <td style={{ fontWeight: 600 }}>{sos.user_id}</td>
                        <td>
                          <a 
                            href={`https://www.google.com/maps?q=${sos.latitude},${sos.longitude}`} 
                            target="_blank" 
                            rel="noreferrer"
                            style={{ color: 'var(--accent-blue)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '13px' }}
                          >
                            <MapPin size={13} /> {latStr}, {lonStr}
                          </a>
                        </td>
                        <td>
                          <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                            {relayPath.length > 0 ? relayPath.join(' ➔ ') : 'Direct Link'}
                          </span>
                        </td>
                        <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                          <Clock size={12} style={{ display: 'inline', marginRight: '4px' }} />
                          {timeFormatted}
                        </td>
                        <td>
                          <span className={`badge ${sos.status === 'QUEUED' ? 'badge-urgent' : sos.status === 'DISPATCHED' ? 'badge-warning' : 'badge-success'}`}>
                            {sos.status}
                          </span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: '6px' }}>
                            {sos.status !== 'DISPATCHED' && (
                              <button 
                                className="btn btn-primary btn-sm"
                                onClick={() => handleUpdateSosStatus(sos.id, 'DISPATCHED')}
                              >
                                Dispatch Unit
                              </button>
                            )}
                            {sos.status !== 'RESOLVED' && (
                              <button 
                                className="btn btn-success btn-sm"
                                onClick={() => handleUpdateSosStatus(sos.id, 'RESOLVED')}
                              >
                                Mark Resolved
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 4: MESH TOPOLOGY TAB */}
        {/* ========================================================================= */}
        {activeTab === 'mesh' && (
          <div>
            {/* Mesh Network Stats */}
            <div className="stats-grid">
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>ACTIVE RELAY NODES</span>
                <div className="stat-value">{meshNodes.length}</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-green)' }}>100% P2P Reachability</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>PACKET DEDUPLICATION</span>
                <div className="stat-value">99.8%</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-cyan)' }}>LRU Cache Active</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>CRDT CONFLICTS RESOLVED</span>
                <div className="stat-value">{conflicts.length}</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-indigo)' }}>Deterministic LWW</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>AVG HOP LATENCY</span>
                <div className="stat-value">38 ms</div>
                <div style={{ fontSize: '12px', color: 'var(--accent-green)' }}>Zero Internet Overhead</div>
              </div>
            </div>

            {/* Mesh Nodes Visual Grid */}
            <div className="data-table-card">
              <div className="table-header">
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600 }}>Active Mesh Peer Topology</h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Discovered Bluetooth Low Energy & Wi-Fi Direct nodes in disaster sector</p>
                </div>
              </div>

              <div className="mesh-nodes-grid">
                {meshNodes.map(node => (
                  <div key={node.id} className="mesh-node-card">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                      <div style={{ fontWeight: 700, fontSize: '15px' }}>{node.name}</div>
                      <span className="badge badge-success">{node.status}</span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--accent-indigo)', fontWeight: 600, marginBottom: '12px' }}>
                      {node.role}
                    </div>

                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span>Signal (RSSI):</span>
                        <span style={{ fontWeight: 600, color: '#fff' }}>{node.rssi} dBm</span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span>Battery Level:</span>
                        <span style={{ fontWeight: 600, color: node.battery > 50 ? 'var(--accent-green)' : 'var(--accent-yellow)' }}>{node.battery}%</span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span>Connected Peers:</span>
                        <span style={{ fontWeight: 600, color: '#fff' }}>{node.peers} Nodes</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* CRDT Conflict Audit Log */}
            <div className="data-table-card">
              <div className="table-header">
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600 }}>CRDT Synchronization Conflict Audit</h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Automated mathematical resolution logs for concurrent offline mutations</p>
                </div>
              </div>
              {conflicts.length === 0 ? (
                <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  No concurrent vector clock conflicts detected. All mobile nodes in sync!
                </div>
              ) : (
                <table>
                  <thead>
                    <tr>
                      <th>Entity Type</th>
                      <th>Entity ID</th>
                      <th>Client ID</th>
                      <th>Winning Payload</th>
                      <th>Resolved Timestamp</th>
                    </tr>
                  </thead>
                  <tbody>
                    {conflicts.map(c => (
                      <tr key={c.id}>
                        <td><span className="badge badge-info">{c.entity_type}</span></td>
                        <td style={{ fontFamily: 'monospace' }}>{c.entity_id}</td>
                        <td>{c.client_id}</td>
                        <td style={{ fontSize: '12px', fontFamily: 'monospace' }}>{JSON.stringify(c.winning_payload)}</td>
                        <td>{new Date(c.resolved_at).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 5: RESOURCES & AI FORECAST TAB */}
        {/* ========================================================================= */}
        {activeTab === 'resources' && (
          <div>
            <div className="stats-grid">
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>TOTAL CLEAN WATER</span>
                <div className="stat-value">
                  {shelters.reduce((acc, s) => acc + ((s.equipment_json && s.equipment_json.clean_water_liters) || 2500), 0).toLocaleString()} L
                </div>
                <div style={{ fontSize: '12px', color: 'var(--accent-blue)' }}>Across all shelters</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>EMERGENCY MEALS</span>
                <div className="stat-value">
                  {shelters.reduce((acc, s) => acc + ((s.equipment_json && s.equipment_json.food_meals) || (s.capacity * 3)), 0).toLocaleString()}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--accent-yellow)' }}>Rations Available</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>FIRST AID KITS</span>
                <div className="stat-value">
                  {shelters.reduce((acc, s) => acc + ((s.equipment_json && s.equipment_json.first_aid_kits) || 25), 0)}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--accent-green)' }}>Triage Ready</div>
              </div>
              <div className="stat-card">
                <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 600 }}>BACKUP GENERATORS</span>
                <div className="stat-value">
                  {shelters.reduce((acc, s) => acc + ((s.equipment_json && s.equipment_json.generators) || 1), 0)}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--accent-cyan)' }}>Power Grid Redundancy</div>
              </div>
            </div>

            {/* AI Shortage Predictor Table */}
            <div className="data-table-card">
              <div className="table-header">
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600 }}>AI Resource Shortage Predictor</h3>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                    Calculates depletion hours based on occupant burn-rate (3.5L water/day, 2 meals/day, 0.1 kits/day)
                  </p>
                </div>
              </div>

              <table>
                <thead>
                  <tr>
                    <th>Shelter</th>
                    <th>Occupants</th>
                    <th>Water Depletion</th>
                    <th>Food Depletion</th>
                    <th>Medical Depletion</th>
                    <th>Risk Assessment</th>
                  </tr>
                </thead>
                <tbody>
                  {shelters.map(s => {
                    const occ = Math.max(1, s.current_occupancy || 1);
                    const equip = s.equipment_json || {};
                    const water = equip.clean_water_liters || 2500;
                    const meals = equip.food_meals || (s.capacity * 3);
                    const kits = equip.first_aid_kits || 25;

                    const waterHours = (water / (occ * (3.5 / 24.0))).toFixed(1);
                    const foodHours = (meals / (occ * (2.0 / 24.0))).toFixed(1);
                    const medHours = (kits / (occ * (0.1 / 24.0))).toFixed(1);

                    const minHours = Math.min(Number(waterHours), Number(foodHours), Number(medHours));
                    const isCritical = minHours < 24;
                    const isWarning = minHours >= 24 && minHours < 72;

                    return (
                      <tr key={s.id}>
                        <td style={{ fontWeight: 600 }}>{s.name}</td>
                        <td>{occ} persons</td>
                        <td>
                          <span style={{ color: Number(waterHours) < 24 ? '#f87171' : '#fff' }}>
                            💧 {waterHours} hrs ({Math.round(water)} L)
                          </span>
                        </td>
                        <td>
                          <span style={{ color: Number(foodHours) < 24 ? '#f87171' : '#fff' }}>
                            🍞 {foodHours} hrs ({meals} rations)
                          </span>
                        </td>
                        <td>
                          <span>🩹 {medHours} hrs ({kits} kits)</span>
                        </td>
                        <td>
                          <span className={`badge ${isCritical ? 'badge-urgent' : isWarning ? 'badge-warning' : 'badge-success'}`}>
                            {isCritical ? 'CRITICAL (<24h)' : isWarning ? 'WARNING (<72h)' : 'ADEQUATE'}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* MODAL: ADD SHELTER */}
        {/* ========================================================================= */}
        {isAddShelterOpen && (
          <div className="modal-overlay" onClick={() => setIsAddShelterOpen(false)}>
            <div className="modal-card" onClick={(e) => e.stopPropagation()}>
              <div className="modal-header">
                <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Register New Shelter</h3>
                <X size={20} style={{ cursor: 'pointer' }} onClick={() => setIsAddShelterOpen(false)} />
              </div>
              <form onSubmit={handleCreateShelter}>
                <div className="form-group">
                  <label className="form-label">Shelter Name</label>
                  <input 
                    type="text" 
                    className="form-input" 
                    required 
                    placeholder="e.g. Westside Community Center"
                    value={newShelterForm.name}
                    onChange={(e) => setNewShelterForm({ ...newShelterForm, name: e.target.value })}
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div className="form-group">
                    <label className="form-label">Total Capacity</label>
                    <input 
                      type="number" 
                      className="form-input" 
                      required 
                      value={newShelterForm.capacity}
                      onChange={(e) => setNewShelterForm({ ...newShelterForm, capacity: parseInt(e.target.value) || 100 })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Current Occupancy</label>
                    <input 
                      type="number" 
                      className="form-input" 
                      value={newShelterForm.current_occupancy}
                      onChange={(e) => setNewShelterForm({ ...newShelterForm, current_occupancy: parseInt(e.target.value) || 0 })}
                    />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div className="form-group">
                    <label className="form-label">Latitude</label>
                    <input 
                      type="number" 
                      step="0.0001" 
                      className="form-input" 
                      value={newShelterForm.latitude}
                      onChange={(e) => setNewShelterForm({ ...newShelterForm, latitude: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Longitude</label>
                    <input 
                      type="number" 
                      step="0.0001" 
                      className="form-input" 
                      value={newShelterForm.longitude}
                      onChange={(e) => setNewShelterForm({ ...newShelterForm, longitude: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Hazard Rating (0 to 5)</label>
                  <input 
                    type="number" 
                    min="0" 
                    max="5" 
                    className="form-input" 
                    value={newShelterForm.hazard_rating}
                    onChange={(e) => setNewShelterForm({ ...newShelterForm, hazard_rating: parseInt(e.target.value) || 0 })}
                  />
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setIsAddShelterOpen(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary">
                    Create Shelter
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* MODAL: DISPATCH / SIMULATE SOS */}
        {/* ========================================================================= */}
        {isAddSosOpen && (
          <div className="modal-overlay" onClick={() => setIsAddSosOpen(false)}>
            <div className="modal-card" onClick={(e) => e.stopPropagation()}>
              <div className="modal-header">
                <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Simulate Distress Beacon</h3>
                <X size={20} style={{ cursor: 'pointer' }} onClick={() => setIsAddSosOpen(false)} />
              </div>
              <form onSubmit={handleCreateSos}>
                <div className="form-group">
                  <label className="form-label">User / Device Identifier</label>
                  <input 
                    type="text" 
                    className="form-input" 
                    required 
                    value={newSosForm.user_id}
                    onChange={(e) => setNewSosForm({ ...newSosForm, user_id: e.target.value })}
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div className="form-group">
                    <label className="form-label">Latitude</label>
                    <input 
                      type="number" 
                      step="0.0001" 
                      className="form-input" 
                      value={newSosForm.latitude}
                      onChange={(e) => setNewSosForm({ ...newSosForm, latitude: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Longitude</label>
                    <input 
                      type="number" 
                      step="0.0001" 
                      className="form-input" 
                      value={newSosForm.longitude}
                      onChange={(e) => setNewSosForm({ ...newSosForm, longitude: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Initial Status</label>
                  <select 
                    className="form-input"
                    value={newSosForm.status}
                    onChange={(e) => setNewSosForm({ ...newSosForm, status: e.target.value })}
                  >
                    <option value="QUEUED">QUEUED (Urgent)</option>
                    <option value="DISPATCHED">DISPATCHED</option>
                    <option value="RESOLVED">RESOLVED</option>
                  </select>
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                  <button type="button" className="btn btn-secondary" onClick={() => setIsAddSosOpen(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-danger">
                    Broadcast Beacon
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
