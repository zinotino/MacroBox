# MacroMaster Real-Time Dashboard System

A fully reliable system for recording user interactions, providing real-time updates, and displaying comprehensive metrics on a live dashboard with data persistence and error recovery.

## 🚀 Quick Start

1. **Start the System:**
   ```bash
   cd dashboard
   run_realtime_system.bat
   ```

2. **Start the AHK Macro System:**
   ```bash
   # Run the updated AHK script
   src/MacroLauncherX46.ahk
   ```

3. **Open Dashboard:**
   - Navigate to: http://localhost:5002
   - Enter session ID (default: shown in AHK status)

## 🏗️ System Architecture

### Components

1. **SQLite Database** (`macromaster_realtime.db`)
   - Stores all user interactions, sessions, and metrics
   - Located in `%USERPROFILE%\Documents\MacroMaster\`
   - WAL mode enabled for concurrent access

2. **Data Ingestion Service** (Port 5001)
   - HTTP API for receiving data from AHK script
   - Stores data in database with error handling
   - Provides metrics and session management endpoints

3. **Real-Time Dashboard** (Port 5002)
   - WebSocket-based live updates
   - Interactive charts and metrics
   - Multi-session support

4. **AHK Macro System** (`MacroLauncherX46.ahk`)
   - Enhanced with real-time data sending
   - Automatic fallback to CSV if service unavailable
   - Session-based tracking

### Data Flow

```
AHK Script → HTTP POST → Ingestion Service → SQLite Database
                                      ↓
WebSocket ← Dashboard ← Database Metrics Cache
```

## 📊 Features

### Real-Time Updates
- **Instant Dashboard Updates**: WebSocket connections provide live data
- **Session-Based Tracking**: Isolated data per user session
- **Automatic Metrics Calculation**: Real-time computation of performance stats

### Data Persistence
- **SQLite Database**: ACID-compliant storage
- **Automatic Backups**: Daily backups with recovery
- **Data Validation**: Integrity checks and error recovery

### Error Recovery
- **Service Fallback**: AHK falls back to CSV if real-time service unavailable
- **Transaction Rollback**: Database operations are atomic
- **Health Monitoring**: Automatic service health checks

### Multi-User Support
- **Session Isolation**: Each user session is independent
- **Concurrent Access**: Multiple users can use the system simultaneously
- **Session Management**: Start/end sessions with proper cleanup

## 🔧 Configuration

### Service Ports
- Data Ingestion: `5001`
- Dashboard: `5002`
- Modify in batch files or Python scripts as needed

### Database Location
- Default: `%USERPROFILE%\Documents\MacroMaster\macromaster_realtime.db`
- Can be customized in `database_schema.py`

### Session Configuration
- Session ID format: `sess_YYYYMMDD_HHMMSS`
- Auto-generated on AHK startup
- Can be manually specified in dashboard

## 📈 Dashboard Features

### Live Metrics
- **Total Boxes**: Cumulative boxes processed
- **Session Duration**: Active labeling time
- **Average Speed**: Boxes per second
- **Current Speed**: Recent performance (10-minute window)

### Interactive Charts
- **Speed Over Time**: Real-time performance graph
- **Execution Time Distribution**: Statistical analysis
- **Degradation Types**: Breakdown of image quality issues

### Raw Data Summary
- **Session Info**: Executions, macros, buttons used
- **Performance Metrics**: Detailed timing and efficiency data
- **Degradation Summary**: Quality issue statistics

## 🛠️ API Endpoints

### Data Ingestion Service (Port 5001)

#### POST `/ingest/interaction`
Record a user interaction.
```json
{
  "session_id": "sess_20231201_143022",
  "interaction_type": "macro_execution",
  "button_key": "Num5",
  "execution_time_ms": 1250,
  "total_boxes": 5,
  "degradation_assignments": "smudge,glare",
  "degradation_counts": {"smudge": 1, "glare": 1}
}
```

#### POST `/session/start`
Start a new session.
```json
{
  "session_id": "sess_20231201_143022",
  "username": "john_doe",
  "canvas_mode": "wide"
}
```

#### GET `/metrics/{session_id}`
Get real-time metrics for a session.

#### GET `/interactions/{session_id}`
Get recent interactions (default: last 100).

### Dashboard WebSocket Events

#### Client → Server
- `join_session`: Join a session for updates
- `leave_session`: Leave current session
- `request_update`: Request immediate data refresh

#### Server → Client
- `initial_data`: Complete dashboard data on join
- `realtime_update`: Incremental updates during session
- `error`: Error notifications

## 🔄 Migration from CSV System

The new system maintains backward compatibility:

1. **Automatic Fallback**: If real-time services are unavailable, AHK writes to CSV
2. **Data Import**: CSV data can be imported into the database
3. **Dual Operation**: Both systems can run simultaneously

## 🧪 Testing

### Health Checks
```bash
# Check ingestion service
curl http://localhost:5001/health

# Check dashboard service
curl http://localhost:5002/health
```

### Manual Testing
1. Start services with `run_realtime_system.bat`
2. Run AHK script `MacroLauncherX46.ahk`
3. Open dashboard at http://localhost:5002
4. Enter session ID from AHK status bar
5. Perform macro executions and watch live updates

## 🚨 Troubleshooting

### Services Won't Start
- Check Python installation and PATH
- Verify port availability (5001, 5002)
- Check firewall settings

### No Real-Time Updates
- Verify WebSocket connection in browser dev tools
- Check AHK script is sending data to correct port
- Review service logs for errors

### Database Issues
- Check file permissions on Documents folder
- Verify SQLite installation
- Use database backup recovery

### AHK Fallback Mode
- If "Real-time service unavailable" appears, services may not be running
- Check Windows Firewall and antivirus
- Verify PowerShell execution policy

## 📁 File Structure

```
MacroMasterV555/
├── dashboard/
│   ├── database_schema.py          # SQLite database management
│   ├── data_ingestion_service.py   # HTTP ingestion API
│   ├── realtime_dashboard.py       # WebSocket dashboard
│   ├── requirements.txt            # Python dependencies
│   └── run_realtime_system.bat     # Startup script
├── src/
│   ├── MacroLauncherX45.ahk        # Original AHK script
│   └── MacroLauncherX46.ahk        # Real-time enabled AHK
├── data/
│   └── master_stats.csv            # Fallback CSV storage
└── README_REALTIME.md              # This documentation
```

## 🔐 Security Considerations

- Services run on localhost only
- No authentication required (single-user system)
- Database stored in user Documents folder
- WebSocket connections are local

## 🚀 Performance

- **Database**: WAL mode for concurrent reads/writes
- **WebSocket**: Efficient real-time updates
- **Caching**: Metrics cached for fast dashboard loads
- **Cleanup**: Automatic old data removal

## 📞 Support

For issues:
1. Check service logs in command windows
2. Verify all services are running
3. Test with health check endpoints
4. Review AHK status messages

The system is designed for reliability with multiple fallback mechanisms and comprehensive error handling.