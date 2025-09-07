class ASEWindow {
  constructor() {
    this.isOpen = false;
    this.isActive = false;
    this.selectedLane = null;

    this.initElements();
    this.setupListeners();
    this.initNui();
    this.setupDrag();
  }

  initElements() {
    this.window = document.getElementById('ase-window');
    this.powerBtn = document.getElementById('ase-power-btn');
    this.closeBtn = document.getElementById('ase-close-btn');
    this.frontSpeed = document.getElementById('front-speed');
    this.rearSpeed = document.getElementById('rear-speed');
    this.patrolSpeed = document.getElementById('patrol-speed');
    this.laneButtons = document.querySelectorAll('.lane-btn');
  }

  setupListeners() {
    this.powerBtn.addEventListener('click', () => this.togglePower());
    this.closeBtn.addEventListener('click', () => this.close());

    this.laneButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const lane = parseInt(btn.dataset.lane);
        this.selectLane(lane);
      });
    });

    document.addEventListener('keydown', (e) => {
      if (!this.isOpen) return;
      switch (e.key.toLowerCase()) {
        case 'escape':
          this.close();
          break;
        case 'p':
          this.togglePower();
          break;
        case '1': case '2': case '3': case '4': case '5': case '6':
          this.selectLane(parseInt(e.key));
          break;
      }
    });
  }

  setupDrag() {
    const header = this.window.querySelector('.ase-header');
    let isDragging = false;
    let offset = { x: 0, y: 0 };

    header.addEventListener('mousedown', (e) => {
      isDragging = true;
      offset.x = e.clientX - this.window.offsetLeft;
      offset.y = e.clientY - this.window.offsetTop;
      e.preventDefault();
    });

    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return;
      this.window.style.left = (e.clientX - offset.x) + 'px';
      this.window.style.top = (e.clientY - offset.y) + 'px';
    });

    document.addEventListener('mouseup', () => {
      isDragging = false;
    });
  }

  initNui() {
    window.addEventListener('message', (event) => {
      const data = event.data;
      switch (data.action) {
        case 'ASE_OPEN':
          this.open();
          break;
        case 'ASE_CLOSE':
          this.close();
          break;
        case 'RADAR_SPEED_DETECTED':
          this.onSpeed(data);
          break;
        case 'RADAR_PATROL_SPEED':
          this.updatePatrolSpeed(data.speed);
          break;
      }
    });
  }

  open() {
    this.isOpen = true;
    this.window.style.display = 'block';
    this.window.style.top = '20px';
    this.window.style.left = '50%';
    this.window.style.transform = 'translateX(-50%)';
    this.sendNui('aseOpened');
  }

  close() {
    this.isOpen = false;
    this.isActive = false;
    this.window.style.display = 'none';
    this.clearData();
    this.sendNui('aseClosed');
  }

  togglePower() {
    this.isActive = !this.isActive;
    this.powerBtn.classList.toggle('active', this.isActive);
    if (!this.isActive) {
      this.clearData();
    }
    this.sendNui('asePowerToggle', { active: this.isActive });
  }

  selectLane(lane) {
    this.selectedLane = this.selectedLane === lane ? null : lane;
    this.laneButtons.forEach(btn => {
      btn.classList.toggle('active', parseInt(btn.dataset.lane) === this.selectedLane);
    });
    this.sendNui('aseLaneSelected', { lane: this.selectedLane });
  }

  onSpeed(data) {
    if (!this.isActive) return;
    const { lane, speed, direction } = data;
    const display = (direction === 'front' || lane <= 3) ? this.frontSpeed : this.rearSpeed;
    display.textContent = String(speed).padStart(3, '0');
    this.sendNui('aseSpeedDetected', data);
  }

  updatePatrolSpeed(speed) {
    this.patrolSpeed.textContent = String(speed).padStart(3, '0');
  }

  clearData() {
    this.frontSpeed.textContent = '000';
    this.rearSpeed.textContent = '000';
    this.patrolSpeed.textContent = '000';
    this.selectLane(null);
  }

  sendNui(action, data = {}) {
    fetch(`https://frp_mdtui/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    }).catch(err => console.error('[ASEWindow] NUI error for', action, err));
  }
}

const aseWindow = new ASEWindow();
window.ASEWindow = ASEWindow;
