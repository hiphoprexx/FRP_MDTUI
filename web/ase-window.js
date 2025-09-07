// ASE Speed Enforcement Window - Compact Modern Interface
class ASEWindow {
    constructor() {
        this.isOpen = false;
        this.isActive = false;
        this.isLaserMode = false;
        this.isScanning = false;
        this.patrolSpeed = 0;
        this.currentPlate = null;
        this.speedLimit = 35;
        
        this.initializeElements();
        this.setupEventListeners();
        this.initializeNUIListener();
        this.setupDragFunctionality();
    }

    initializeElements() {
        this.window = document.getElementById('ase-window');
        this.powerBtn = document.getElementById('ase-power-btn');
        this.closeBtn = document.getElementById('ase-close-btn');
        
        // Speed displays
        this.frontSpeed = document.getElementById('front-speed');
        this.rearSpeed = document.getElementById('rear-speed');
        
        // Plate elements
        this.plateGlyphs = document.getElementById('plate-glyphs');
        this.plateText = document.getElementById('plate-text');
        this.plateSource = document.getElementById('plate-source');
        
        // Status indicators
        this.radarStatusDot = document.getElementById('radar-status-dot');
        this.laserStatusDot = document.getElementById('laser-status-dot');
        this.plateStatusDot = document.getElementById('plate-status-dot');
        this.patrolSpeedValue = document.getElementById('patrol-speed');
    }

    setupEventListeners() {
        // Power button
        this.powerBtn.addEventListener('click', () => {
            this.togglePower();
        });

        // Close button
        this.closeBtn.addEventListener('click', () => {
            this.close();
        });

        // Keyboard controls
        document.addEventListener('keydown', (event) => {
            if (!this.isOpen) return;
            
            switch (event.key.toLowerCase()) {
                case 'escape':
                    this.close();
                    break;
                case 'p':
                    this.togglePower();
                    break;
                case 'l':
                    this.toggleLaserMode();
                    break;
            }
        });
    }

    setupDragFunctionality() {
        const header = this.window.querySelector('.ase-header');
        let isDragging = false;
        let dragStart = { x: 0, y: 0 };

        header.addEventListener('mousedown', (e) => {
            isDragging = true;
            dragStart = {
                x: e.clientX - this.getWindowPosition().x,
                y: e.clientY - this.getWindowPosition().y
            };
            this.window.classList.add('dragging');
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (isDragging) {
                const newX = e.clientX - dragStart.x;
                const newY = e.clientY - dragStart.y;
                
                // Keep window within viewport bounds
                const maxX = window.innerWidth - this.window.offsetWidth;
                const maxY = window.innerHeight - this.window.offsetHeight;
                
                this.window.style.left = Math.max(0, Math.min(newX, maxX)) + 'px';
                this.window.style.top = Math.max(0, Math.min(newY, maxY)) + 'px';
            }
        });

        document.addEventListener('mouseup', () => {
            isDragging = false;
            this.window.classList.remove('dragging');
        });

        // Resize functionality
        const resizeHandle = this.window.querySelector('.ase-resize-handle');
        let isResizing = false;
        let resizeStart = { x: 0, y: 0, width: 0, height: 0 };

        resizeHandle.addEventListener('mousedown', (e) => {
            isResizing = true;
            resizeStart = {
                x: e.clientX,
                y: e.clientY,
                width: this.window.offsetWidth,
                height: this.window.offsetHeight
            };
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (isResizing) {
                const deltaX = e.clientX - resizeStart.x;
                const deltaY = e.clientY - resizeStart.y;
                
                const newWidth = Math.max(280, resizeStart.width + deltaX);
                const newHeight = Math.max(160, resizeStart.height + deltaY);
                
                this.window.style.width = newWidth + 'px';
                this.window.style.height = newHeight + 'px';
            }
        });

        document.addEventListener('mouseup', () => {
            isResizing = false;
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
                case 'ALPR_SCAN':
                    this.onPlateDetected(data);
                    break;
                case 'plateDetected':
                    this.onPlateDetected(data);
                    break;
            }
        });
    }

    getWindowPosition() {
        const rect = this.window.getBoundingClientRect();
        return { x: rect.left, y: rect.top };
    }

    open(data = {}) {
        console.log('[ASEWindow] Opening ASE interface');
        this.isOpen = true;
        this.window.style.display = 'block';
        
        // Position window in center if not positioned
        if (!this.window.style.left && !this.window.style.top) {
            this.window.style.left = '50%';
            this.window.style.top = '50%';
            this.window.style.transform = 'translate(-50%, -50%)';
        }
        
        this.updateUI();
        this.sendNui('aseOpened', {});
    }

    close() {
        console.log('[ASEWindow] Closing ASE interface');
        this.isOpen = false;
        this.isActive = false;
        this.isLaserMode = false;
        this.isScanning = false;
        this.window.style.display = 'none';
        this.clearAllData();
        this.sendNui('aseClosed', {});
    }

    togglePower() {
        this.isActive = !this.isActive;
        console.log('[ASEWindow] Power toggled:', this.isActive ? 'ON' : 'OFF');
        
        if (!this.isActive) {
            this.isLaserMode = false;
            this.isScanning = false;
            this.clearAllData();
        }
        
        this.updateUI();
        this.sendNui('asePowerToggle', { active: this.isActive });
    }

    toggleLaserMode() {
        if (!this.isActive) return;
        
        this.isLaserMode = !this.isLaserMode;
        console.log('[ASEWindow] Laser mode toggled:', this.isLaserMode ? 'ON' : 'OFF');
        
        this.updateUI();
        this.sendNui('aseLaserToggle', { laserMode: this.isLaserMode });
    }

    onSpeedDetected(data) {
        if (!this.isActive) return;
        
        const { lane, speed, direction } = data;
        console.log('[ASEWindow] Speed detected:', speed, 'MPH in', direction, 'lane', lane);
        
        // Update appropriate speed display
        if (direction === 'front' || lane <= 3) {
            this.updateSpeedDisplay(this.frontSpeed, speed);
        } else {
            this.updateSpeedDisplay(this.rearSpeed, speed);
        }
        
        this.sendNui('aseSpeedDetected', { lane, speed, direction });
    }

    onLaserTarget(data) {
        if (!this.isLaserMode) return;
        
        const { lane, speed, distance, plate } = data;
        console.log('[ASEWindow] Laser target:', speed, 'MPH in lane', lane);
        
        // Update speed display based on lane
        if (lane <= 3) {
            this.updateSpeedDisplay(this.frontSpeed, speed);
        } else {
            this.updateSpeedDisplay(this.rearSpeed, speed);
        }
        
        // Update plate if provided
        if (plate) {
            this.updatePlate(plate, 'LASER');
        }
        
        this.sendNui('aseLaserTarget', { lane, speed, distance, plate });
    }

    onPlateDetected(data) {
        if (!data || !data.plate) return;
        
        const { plate, source } = data;
        console.log('[ASEWindow] Plate detected:', plate, 'from', source);
        
        this.updatePlate(plate, source || 'ALPR');
        this.isScanning = true;
        this.updateUI();
        
        this.sendNui('asePlateDetected', { plate, source });
    }

    updateSpeedDisplay(element, speed) {
        if (!element) return;
        
        // Format as 3-digit display like radar gun
        element.textContent = speed.toString().padStart(3, '0');
        
        // Remove existing color classes
        element.classList.remove('under-limit', 'close-limit', 'over-limit');
        
        // Add appropriate color class
        if (speed < this.speedLimit - 5) {
            element.classList.add('under-limit');
        } else if (speed <= this.speedLimit + 5) {
            element.classList.add('close-limit');
        } else {
            element.classList.add('over-limit');
        }
    }

    updatePlate(plate, source) {
        this.currentPlate = plate;
        this.plateText.textContent = plate;
        this.plateSource.textContent = source;
        
        // Render plate glyphs
        this.renderPlateGlyphs(plate);
    }

    renderPlateGlyphs(plateNumber) {
        if (!this.plateGlyphs) return;
        
        const safe = (plateNumber || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        if (safe.length === 0) {
            this.plateGlyphs.innerHTML = '';
            return;
        }
        
        const basePath = 'plates/blue_27x55';
        const html = Array.from(safe).map(ch => {
            const name = /[0-9]/.test(ch) ? ch : ch;
            return `<img class="glyph" alt="${ch}" src="${basePath}/${name}.png">`;
        }).join('');
        
        this.plateGlyphs.innerHTML = html;
    }

    updatePatrolSpeed(speed) {
        this.patrolSpeed = speed;
        this.patrolSpeedValue.textContent = speed.toString().padStart(3, '0');
    }

    clearAllData() {
        // Clear speed displays with radar gun format
        this.frontSpeed.textContent = '000';
        this.rearSpeed.textContent = '000';
        this.frontSpeed.classList.remove('under-limit', 'close-limit', 'over-limit');
        this.rearSpeed.classList.remove('under-limit', 'close-limit', 'over-limit');
        
        // Clear plate data
        this.currentPlate = null;
        this.plateText.textContent = 'NO PLATE';
        this.plateSource.textContent = '--';
        this.plateGlyphs.innerHTML = '';
        
        // Reset scanning status
        this.isScanning = false;
    }

    updateUI() {
        // Update power button
        this.powerBtn.classList.toggle('active', this.isActive);
        
        // Update status indicators
        this.radarStatusDot.classList.toggle('active', this.isActive);
        this.laserStatusDot.classList.toggle('active', this.isLaserMode);
        this.plateStatusDot.classList.toggle('scanning', this.isScanning);
        
        // Update patrol speed with 3-digit format
        this.patrolSpeedValue.textContent = this.patrolSpeed.toString().padStart(3, '0');
    }

    sendNui(action, data = {}) {
        fetch(`https://frp_mdtui/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(data),
        }).then(resp => resp.json()).then(resp => {
            console.log(`[ASEWindow] NUI callback response: ${action}`, resp);
        }).catch(error => {
            console.error(`[ASEWindow] NUI callback error for ${action}:`, error);
        });
    }
}

// Initialize the ASE window system
const aseWindow = new ASEWindow();

// Export for use in other scripts
window.ASEWindow = ASEWindow;

// Initialize ASE window when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('[ASEWindow] DOM loaded, initializing ASE window');
    
    // Check if ASE window exists
    const aseWindowElement = document.getElementById('ase-window');
    if (aseWindowElement) {
        console.log('[ASEWindow] ASE window found, setting up interface');
        
        // Hide the ASE window by default
        aseWindowElement.style.display = 'none';
        console.log('[ASEWindow] ASE window hidden by default');
    } else {
        console.error('[ASEWindow] ASE window not found during initialization');
    }
});
