// FRP MDT UI - Modern Speed Radar System
// Handles lane targeting, speed detection, and laser mode

class SpeedRadarSystem {
    constructor() {
        this.isActive = false;
        this.isLaserMode = false;
        this.selectedLane = null; // No lane selected by default
        this.speedLimit = 35; // Default speed limit
        this.lockedVehicles = new Set();
        this.currentTarget = null;
        this.patrolSpeed = 0;
        this.showAllLanes = true; // Show all lanes by default
        
        this.initializeElements();
        this.setupEventListeners();
        this.initializeNUIListener();
        this.updateUI();
    }

    initializeElements() {
        this.container = document.getElementById('ase-container');
        this.powerBtn = document.getElementById('radar-power-btn');
        this.laserBtn = document.getElementById('radar-laser-btn');
        this.closeBtn = document.getElementById('radar-close');
        
        // Status indicators
        this.radarStatus = document.getElementById('radar-status');
        this.laserStatus = document.getElementById('laser-status');
        this.patrolSpeedDisplay = document.getElementById('patrol-speed');
        
        // Lane selection
        this.lanes = document.querySelectorAll('.lane');
        
        // Speed displays
        this.frontSpeeds = {
            1: document.getElementById('front-speed-1'),
            2: document.getElementById('front-speed-2'),
            3: document.getElementById('front-speed-3')
        };
        this.rearSpeeds = {
            4: document.getElementById('rear-speed-4'),
            5: document.getElementById('rear-speed-5'),
            6: document.getElementById('rear-speed-6')
        };
        
        // Lock buttons
        this.frontLockBtn = document.getElementById('front-lock-btn');
        this.rearLockBtn = document.getElementById('rear-lock-btn');
        
        // Vehicle info
        this.targetStatus = document.getElementById('target-status');
        this.targetSpeed = document.getElementById('target-speed');
        this.targetDistance = document.getElementById('target-distance');
        this.targetPlate = document.getElementById('target-plate');
    }

    setupEventListeners() {
        // Power button
        this.powerBtn.addEventListener('click', () => {
            this.togglePower();
        });

        // Laser button
        this.laserBtn.addEventListener('click', () => {
            this.toggleLaserMode();
        });

        // Close button
        this.closeBtn.addEventListener('click', () => {
            this.close();
        });

        // Lane selection
        this.lanes.forEach(lane => {
            lane.addEventListener('click', () => {
                this.selectLane(parseInt(lane.dataset.lane));
            });
        });

        // Lock buttons
        this.frontLockBtn.addEventListener('click', () => {
            this.toggleLock('front');
        });
        this.rearLockBtn.addEventListener('click', () => {
            this.toggleLock('rear');
        });

        // Keyboard controls
        document.addEventListener('keydown', (event) => {
            if (this.container.style.display === 'none') return;
            
            switch (event.key) {
                case 'Escape':
                    this.close();
                    break;
                case 'p':
                case 'P':
                    this.togglePower();
                    break;
                case 'l':
                case 'L':
                    this.toggleLaserMode();
                    break;
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                    this.selectLane(parseInt(event.key));
                    break;
            }
        });

        // Left Alt toggle
        document.addEventListener('keydown', (event) => {
            if (event.altKey && event.key === 'Alt') {
                event.preventDefault();
                this.toggleRadarControls();
            }
        });
    }

    initializeNUIListener() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.action) {
                case 'ASE_OPEN':
                    this.open(data);
                    break;
                case 'ASE_CLOSE':
                    this.close();
                    break;
                case 'RADAR_SPEED_DETECTED':
                    this.onSpeedDetected(data);
                    break;
                case 'RADAR_LASER_TARGET':
                    this.onLaserTarget(data);
                    break;
                case 'RADAR_PATROL_SPEED':
                    this.updatePatrolSpeed(data.speed);
                    break;
                case 'RADAR_PLATE_DETECTED':
                    this.onPlateDetected(data);
                    break;
            }
        });
    }

    open(data = {}) {
        console.log('[SpeedRadar] Opening radar interface');
        this.container.style.display = 'block';
        this.updateUI();
        this.sendNui('radarOpened', {});
    }

    close() {
        console.log('[SpeedRadar] Closing radar interface');
        this.container.style.display = 'none';
        this.isActive = false;
        this.isLaserMode = false;
        this.updateUI();
        this.sendNui('radarClosed', {});
    }

    togglePower() {
        this.isActive = !this.isActive;
        console.log('[SpeedRadar] Power toggled:', this.isActive ? 'ON' : 'OFF');
        
        if (!this.isActive) {
            this.isLaserMode = false;
            this.clearAllSpeeds();
        }
        
        this.updateUI();
        this.sendNui('radarPowerToggle', { active: this.isActive });
    }

    toggleLaserMode() {
        if (!this.isActive) return;
        
        this.isLaserMode = !this.isLaserMode;
        console.log('[SpeedRadar] Laser mode toggled:', this.isLaserMode ? 'ON' : 'OFF');
        
        this.updateUI();
        this.sendNui('radarLaserToggle', { laserMode: this.isLaserMode });
    }

    selectLane(laneNumber) {
        if (laneNumber < 1 || laneNumber > 6) return;
        
        // Toggle lane selection - if already selected, deselect
        if (this.selectedLane === laneNumber) {
            this.selectedLane = null;
            console.log('[SpeedRadar] Deselected lane:', laneNumber);
        } else {
            this.selectedLane = laneNumber;
            console.log('[SpeedRadar] Selected lane:', laneNumber);
        }
        
        // Update lane selection UI
        this.lanes.forEach(lane => {
            lane.classList.remove('selected');
            if (parseInt(lane.dataset.lane) === this.selectedLane) {
                lane.classList.add('selected');
            }
        });
        
        this.sendNui('radarLaneSelected', { lane: this.selectedLane });
    }

    toggleLock(direction) {
        const lockBtn = direction === 'front' ? this.frontLockBtn : this.rearLockBtn;
        const isLocked = lockBtn.classList.contains('locked');
        
        if (isLocked) {
            lockBtn.classList.remove('locked');
            lockBtn.textContent = '🔒';
            this.lockedVehicles.delete(direction);
        } else {
            lockBtn.classList.add('locked');
            lockBtn.textContent = '🔓';
            this.lockedVehicles.add(direction);
        }
        
        console.log('[SpeedRadar] Lock toggled for', direction, ':', !isLocked);
        this.sendNui('radarLockToggle', { direction, locked: !isLocked });
    }

    onSpeedDetected(data) {
        if (!this.isActive) return;
        
        const { lane, speed, direction } = data;
        console.log('[SpeedRadar] Speed detected:', speed, 'MPH in lane', lane, 'direction:', direction);
        
        // Update speed display for all lanes by default
        this.updateSpeedDisplay(lane, speed);
        
        // Update color coding based on speed limit
        this.updateSpeedColor(lane, speed);
        
        // If this lane is locked, update target info
        if (this.lockedVehicles.has(direction)) {
            this.updateTargetInfo(lane, speed, direction);
        }
        
        // If a specific lane is selected, only show that lane's info
        if (this.selectedLane && this.selectedLane !== lane) {
            // Don't update target info for unselected lanes
            return;
        }
        
        this.sendNui('radarSpeedDetected', { lane, speed, direction });
    }

    onLaserTarget(data) {
        if (!this.isLaserMode) return;
        
        const { lane, speed, distance, plate } = data;
        console.log('[SpeedRadar] Laser target:', speed, 'MPH in lane', lane, 'distance:', distance);
        
        this.currentTarget = { lane, speed, distance, plate };
        this.updateTargetInfo(lane, speed, 'laser', distance, plate);
        
        this.sendNui('radarLaserTarget', { lane, speed, distance, plate });
    }

    onPlateDetected(data) {
        const { plate, lane } = data;
        console.log('[SpeedRadar] Plate detected:', plate, 'in lane', lane);
        
        if (this.currentTarget && this.currentTarget.lane === lane) {
            this.currentTarget.plate = plate;
            this.targetPlate.textContent = plate;
        }
        
        this.sendNui('radarPlateDetected', { plate, lane });
    }

    updateSpeedDisplay(lane, speed) {
        const speedElement = this.getSpeedElement(lane);
        if (speedElement) {
            speedElement.textContent = speed.toString().padStart(2, '0');
        }
    }

    updateSpeedColor(lane, speed) {
        const speedElement = this.getSpeedElement(lane);
        if (!speedElement) return;
        
        // Remove existing color classes
        speedElement.classList.remove('under-limit', 'close-limit', 'over-limit');
        
        // Add appropriate color class
        if (speed < this.speedLimit - 5) {
            speedElement.classList.add('under-limit');
        } else if (speed <= this.speedLimit + 5) {
            speedElement.classList.add('close-limit');
        } else {
            speedElement.classList.add('over-limit');
        }
    }

    updateTargetInfo(lane, speed, direction, distance = null, plate = null) {
        this.targetStatus.textContent = `Lane ${lane} (${direction.toUpperCase()})`;
        this.targetSpeed.textContent = speed.toString().padStart(2, '0');
        
        if (distance !== null) {
            this.targetDistance.textContent = distance.toString();
        }
        
        if (plate !== null) {
            this.targetPlate.textContent = plate;
        }
    }

    updatePatrolSpeed(speed) {
        this.patrolSpeed = speed;
        this.patrolSpeedDisplay.textContent = speed.toString();
    }

    getSpeedElement(lane) {
        if (lane >= 1 && lane <= 3) {
            return this.frontSpeeds[lane];
        } else if (lane >= 4 && lane <= 6) {
            return this.rearSpeeds[lane];
        }
        return null;
    }

    clearAllSpeeds() {
        // Clear all speed displays
        Object.values(this.frontSpeeds).forEach(element => {
            element.textContent = '--';
            element.classList.remove('under-limit', 'close-limit', 'over-limit');
        });
        Object.values(this.rearSpeeds).forEach(element => {
            element.textContent = '--';
            element.classList.remove('under-limit', 'close-limit', 'over-limit');
        });
        
        // Clear target info
        this.targetStatus.textContent = 'No Target';
        this.targetSpeed.textContent = '--';
        this.targetDistance.textContent = '--';
        this.targetPlate.textContent = '--';
        
        // Clear locks
        this.lockedVehicles.clear();
        this.frontLockBtn.classList.remove('locked');
        this.rearLockBtn.classList.remove('locked');
        this.frontLockBtn.textContent = '🔒';
        this.rearLockBtn.textContent = '🔒';
        
        // Clear lane selection
        this.selectedLane = null;
        this.lanes.forEach(lane => {
            lane.classList.remove('selected');
        });
    }

    updateUI() {
        // Update status indicators
        this.radarStatus.classList.toggle('active', this.isActive);
        this.radarStatus.querySelector('.status-text').textContent = this.isActive ? 'RADAR ON' : 'RADAR OFF';
        
        this.laserStatus.classList.toggle('active', this.isLaserMode);
        this.laserStatus.querySelector('.status-text').textContent = this.isLaserMode ? 'LASER ON' : 'LASER OFF';
        
        // Update buttons
        this.powerBtn.classList.toggle('active', this.isActive);
        this.laserBtn.classList.toggle('active', this.isLaserMode);
        
        // Update patrol speed
        this.patrolSpeedDisplay.textContent = this.patrolSpeed.toString();
    }

    toggleRadarControls() {
        // Toggle radar power when Left Alt is pressed
        this.togglePower();
    }

    sendNui(action, data = {}) {
        fetch(`https://frp_mdtui/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(data),
        }).then(resp => resp.json()).then(resp => {
            console.log(`[SpeedRadar] NUI callback response: ${action}`, resp);
        }).catch(error => {
            console.error(`[SpeedRadar] NUI callback error for ${action}:`, error);
        });
    }
}

// Initialize the speed radar system
const speedRadarSystem = new SpeedRadarSystem();

// Export for use in other scripts
window.SpeedRadarSystem = SpeedRadarSystem;