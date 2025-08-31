// ECharts Norwegian Healthcare Visualization Controller
// Accessible charts with keyboard navigation and city-specific localization
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "loading", "error", "legend", "accessibility"]
  static values = {
    type: String,
    data: Object,
    locale: { type: String, default: "nb_NO" },
    city: String,
    accessible: { type: Boolean, default: true },
    lazyLoad: { type: Boolean, default: true }
  }

  connect() {
    if (this.lazyLoadValue) {
      this.setupIntersectionObserver()
    } else {
      this.loadChart()
    }
    
    this.setupAccessibility()
    this.setupKeyboardNavigation()
  }

  disconnect() {
    this.destroyChart()
    this.observer?.disconnect()
  }

  // Load ECharts dynamically for performance
  async loadChart() {
    try {
      this.showLoading()
      
      // Load ECharts library dynamically
      if (!window.echarts) {
        await this.loadEChartsLibrary()
      }
      
      await this.initializeChart()
      this.hideLoading()
    } catch (error) {
      this.showError(error.message)
      console.error("ECharts loading failed:", error)
    }
  }

  // Refresh chart with new data
  async refreshChart(event) {
    const newData = event.detail?.data || this.dataValue
    this.dataValue = newData
    
    if (this.chart) {
      this.updateChart()
    } else {
      await this.loadChart()
    }
  }

  // Export chart as image
  exportChart(event) {
    if (!this.chart) return
    
    const format = event.target.dataset.format || 'png'
    const filename = `healthcare_chart_${Date.now()}.${format}`
    
    const dataURL = this.chart.getDataURL({
      type: format,
      pixelRatio: 2,
      backgroundColor: '#ffffff'
    })
    
    this.downloadImage(dataURL, filename)
    
    // Announce to screen readers
    this.announceToScreenReader(`Diagram exportert som ${filename}`)
  }

  // Toggle data series visibility
  toggleSeries(event) {
    if (!this.chart) return
    
    const seriesName = event.target.dataset.series
    const isVisible = !event.target.classList.contains('series-hidden')
    
    this.chart.dispatchAction({
      type: isVisible ? 'legendUnSelect' : 'legendSelect',
      name: seriesName
    })
    
    event.target.classList.toggle('series-hidden')
    
    // Update accessibility description
    this.updateAccessibilityDescription()
  }

  private

  async loadEChartsLibrary() {
    // Load ECharts with Norwegian localization
    return new Promise((resolve, reject) => {
      const script = document.createElement('script')
      script.src = 'https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js'
      script.onload = async () => {
        // Load Norwegian locale
        await this.loadNorwegianLocale()
        resolve()
      }
      script.onerror = () => reject(new Error('Failed to load ECharts library'))
      document.head.appendChild(script)
    })
  }

  async loadNorwegianLocale() {
    // Set up Norwegian number formatting and translations
    echarts.registerLocale('NB', {
      time: {
        month: [
          'Januar', 'Februar', 'Mars', 'April', 'Mai', 'Juni',
          'Juli', 'August', 'September', 'Oktober', 'November', 'Desember'
        ],
        monthAbbr: [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun',
          'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Des'
        ],
        dayOfWeek: [
          'Søndag', 'Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag'
        ],
        dayOfWeekAbbr: ['Søn', 'Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør']
      },
      legend: {
        selector: {
          all: 'Alle',
          inverse: 'Omvendt'
        }
      },
      toolbox: {
        brush: {
          title: {
            rect: 'Rektangel',
            polygon: 'Polygon',
            lineX: 'Horisontal linje',
            lineY: 'Vertikal linje',
            keep: 'Behold',
            clear: 'Fjern'
          }
        },
        dataView: {
          title: 'Datavisning',
          lang: ['Datavisning', 'Lukk', 'Oppdater']
        },
        dataZoom: {
          title: {
            zoom: 'Zoom',
            back: 'Tilbake'
          }
        },
        magicType: {
          title: {
            line: 'Linje',
            bar: 'Stolpe',
            stack: 'Stabel',
            tiled: 'Fliser'
          }
        },
        restore: {
          title: 'Gjenopprett'
        },
        saveAsImage: {
          title: 'Lagre som bilde',
          lang: ['Høyreklikk for å lagre bilde']
        }
      }
    })
  }

  async initializeChart() {
    if (!this.containerTarget) return
    
    // Initialize ECharts instance
    this.chart = echarts.init(this.containerTarget, 'light', {
      locale: 'NB',
      renderer: 'canvas',
      devicePixelRatio: window.devicePixelRatio || 1
    })
    
    // Configure chart options
    const options = await this.buildChartOptions()
    
    // Set chart configuration
    this.chart.setOption(options, true)
    
    // Setup event handlers
    this.setupChartEvents()
    
    // Setup resize handler
    this.setupResizeHandler()
    
    // Update accessibility
    this.updateAccessibilityDescription()
  }

  async buildChartOptions() {
    const baseOptions = {
      // Responsive configuration
      responsive: true,
      
      // Accessibility configuration
      aria: {
        enabled: this.accessibleValue,
        label: {
          enabled: true,
          description: this.getChartDescription()
        },
        decal: {
          show: true // Pattern fills for color blind users
        }
      },
      
      // Animation configuration (reduced motion friendly)
      animation: !window.matchMedia('(prefers-reduced-motion: reduce)').matches,
      animationDuration: 300,
      animationEasing: 'cubicOut',
      
      // Color palette (WCAG AAA compliant)
      color: this.getNorwegianColorPalette(),
      
      // Background and text colors
      backgroundColor: 'transparent',
      textStyle: {
        fontFamily: 'system-ui, -apple-system, sans-serif',
        fontSize: 14,
        color: '#1a1a1a'
      },
      
      // Grid configuration
      grid: {
        left: '10%',
        right: '10%',
        top: '15%',
        bottom: '15%',
        containLabel: true
      },
      
      // Tooltip configuration
      tooltip: {
        trigger: 'axis',
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#ddd',
        borderWidth: 1,
        textStyle: {
          color: '#333',
          fontSize: 14
        },
        formatter: this.tooltipFormatter.bind(this),
        axisPointer: {
          type: 'cross',
          crossStyle: {
            color: '#999'
          }
        }
      },
      
      // Legend configuration
      legend: {
        type: 'scroll',
        orient: 'horizontal',
        top: '5%',
        textStyle: {
          fontSize: 14,
          color: '#333'
        },
        selector: [
          {
            type: 'all',
            title: 'Alle'
          },
          {
            type: 'inverse',
            title: 'Omvendt'
          }
        ]
      },
      
      // Toolbox configuration
      toolbox: {
        feature: {
          dataView: { 
            show: true,
            title: 'Datavisning',
            readOnly: false
          },
          magicType: { 
            show: true,
            type: ['line', 'bar'],
            title: {
              line: 'Linje',
              bar: 'Stolpe'
            }
          },
          restore: { 
            show: true,
            title: 'Gjenopprett'
          },
          saveAsImage: { 
            show: true,
            title: 'Lagre som bilde',
            name: `healthcare_chart_${this.cityValue || 'norway'}_${Date.now()}`
          }
        },
        iconStyle: {
          emphasis: {
            textPosition: 'bottom'
          }
        }
      }
    }
    
    // Merge with chart type specific options
    const typeOptions = await this.getTypeSpecificOptions()
    return this.deepMerge(baseOptions, typeOptions)
  }

  async getTypeSpecificOptions() {
    switch (this.typeValue) {
      case 'healthcare_radar':
        return this.getHealthcareRadarOptions()
      case 'geographic_norway':
        return this.getGeographicNorwayOptions()
      case 'sankey_flow':
        return this.getSankeyFlowOptions()
      case 'time_series':
        return this.getTimeSeriesOptions()
      case 'bar_chart':
        return this.getBarChartOptions()
      case 'pie_chart':
        return this.getPieChartOptions()
      default:
        return this.getDefaultOptions()
    }
  }

  getHealthcareRadarOptions() {
    return {
      radar: {
        indicator: this.dataValue.indicators?.map(indicator => ({
          name: indicator.name,
          max: indicator.max,
          min: indicator.min || 0
        })) || [],
        shape: 'polygon',
        splitNumber: 5,
        splitArea: {
          show: true,
          areaStyle: {
            color: ['rgba(114, 172, 209, 0.1)', 'rgba(114, 172, 209, 0.05)']
          }
        },
        splitLine: {
          lineStyle: {
            color: '#72acd1'
          }
        }
      },
      series: [{
        type: 'radar',
        data: this.dataValue.series || [],
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 2
        },
        areaStyle: {
          opacity: 0.3
        }
      }]
    }
  }

  getGeographicNorwayOptions() {
    return {
      geo: {
        map: 'norway',
        roam: true,
        label: {
          show: true,
          fontSize: 12,
          color: '#333'
        },
        itemStyle: {
          borderColor: '#72acd1',
          borderWidth: 1,
          areaColor: '#f8f9fa'
        },
        emphasis: {
          itemStyle: {
            areaColor: '#e3f2fd'
          },
          label: {
            fontSize: 14,
            fontWeight: 'bold'
          }
        }
      },
      series: [{
        type: 'map',
        geoIndex: 0,
        data: this.getCitySpecificData()
      }]
    }
  }

  getTimeSeriesOptions() {
    return {
      xAxis: {
        type: 'time',
        axisLabel: {
          formatter: (value) => {
            return new Date(value).toLocaleDateString('nb-NO', {
              month: 'short',
              day: 'numeric'
            })
          }
        },
        splitLine: {
          show: false
        }
      },
      yAxis: {
        type: 'value',
        axisLabel: {
          formatter: this.formatNorwegianNumber.bind(this)
        },
        splitLine: {
          lineStyle: {
            color: '#e0e0e0',
            type: 'dashed'
          }
        }
      },
      series: this.dataValue.series?.map(series => ({
        ...series,
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 3
        }
      })) || []
    }
  }

  getBarChartOptions() {
    return {
      xAxis: {
        type: 'category',
        data: this.dataValue.categories || [],
        axisLabel: {
          interval: 0,
          rotate: this.dataValue.categories?.length > 6 ? 45 : 0
        }
      },
      yAxis: {
        type: 'value',
        axisLabel: {
          formatter: this.formatNorwegianNumber.bind(this)
        }
      },
      series: this.dataValue.series?.map(series => ({
        ...series,
        type: 'bar',
        barWidth: '60%',
        itemStyle: {
          borderRadius: [4, 4, 0, 0]
        }
      })) || []
    }
  }

  getPieChartOptions() {
    return {
      series: [{
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['50%', '55%'],
        data: this.dataValue.data || [],
        itemStyle: {
          borderRadius: 8,
          borderColor: '#fff',
          borderWidth: 2
        },
        label: {
          formatter: '{b}: {c} ({d}%)',
          fontSize: 14
        },
        labelLine: {
          length: 20,
          length2: 10
        }
      }]
    }
  }

  getCitySpecificData() {
    if (!this.cityValue) return this.dataValue.data || []
    
    // Filter data for specific city
    const cityData = this.dataValue.cities?.[this.cityValue.toLowerCase()]
    return cityData || this.dataValue.data || []
  }

  getNorwegianColorPalette() {
    // Norwegian flag inspired, WCAG AAA compliant colors
    return [
      '#c41e3a', // Norwegian red
      '#002868', // Norwegian blue  
      '#00843d', // Forest green
      '#f39c12', // Amber
      '#8e44ad', // Purple
      '#e67e22', // Orange
      '#2c3e50', // Dark blue-gray
      '#27ae60', // Green
      '#d35400', // Dark orange
      '#7f8c8d'  // Gray
    ]
  }

  tooltipFormatter(params) {
    if (Array.isArray(params)) {
      const date = params[0]?.axisValue
      let tooltip = date ? `<strong>${this.formatDate(date)}</strong><br/>` : ''
      
      params.forEach(param => {
        const value = this.formatNorwegianNumber(param.value)
        tooltip += `${param.marker} ${param.seriesName}: ${value}<br/>`
      })
      
      return tooltip
    } else {
      const value = this.formatNorwegianNumber(params.value)
      return `${params.marker} ${params.name}: ${value}`
    }
  }

  formatNorwegianNumber(value) {
    if (typeof value !== 'number') return value
    
    return new Intl.NumberFormat('nb-NO', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    }).format(value)
  }

  formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('nb-NO', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  }

  setupChartEvents() {
    if (!this.chart) return
    
    // Click events
    this.chart.on('click', (params) => {
      this.dispatch('chartClick', { detail: params })
      this.announceToScreenReader(`Valgte ${params.name}: ${params.value}`)
    })
    
    // Legend events
    this.chart.on('legendselectchanged', (params) => {
      this.updateAccessibilityDescription()
    })
    
    // Data zoom events
    this.chart.on('datazoom', (params) => {
      this.announceToScreenReader('Diagram zoomet')
    })
  }

  setupResizeHandler() {
    if (!this.chart) return
    
    const resizeObserver = new ResizeObserver(() => {
      this.chart.resize()
    })
    
    resizeObserver.observe(this.containerTarget)
    this.resizeObserver = resizeObserver
  }

  setupIntersectionObserver() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.chart) {
          this.loadChart()
        }
      })
    }, { threshold: 0.1 })
    
    this.observer.observe(this.containerTarget)
  }

  setupAccessibility() {
    if (!this.accessibleValue) return
    
    // Make container focusable
    this.containerTarget.setAttribute('tabindex', '0')
    this.containerTarget.setAttribute('role', 'img')
    this.containerTarget.setAttribute('aria-label', this.getChartDescription())
    
    // Create accessibility description
    this.createAccessibilityDescription()
  }

  setupKeyboardNavigation() {
    this.containerTarget.addEventListener('keydown', (event) => {
      if (!this.chart) return
      
      switch (event.key) {
        case 'ArrowLeft':
        case 'ArrowRight':
          event.preventDefault()
          this.navigateDataPoints(event.key === 'ArrowRight' ? 1 : -1)
          break
        case 'Enter':
        case ' ':
          event.preventDefault()
          this.announceCurrentDataPoint()
          break
        case 'Escape':
          this.chart.dispatchAction({ type: 'restore' })
          this.announceToScreenReader('Diagram tilbakestilt')
          break
      }
    })
  }

  navigateDataPoints(direction) {
    // This would implement keyboard navigation through data points
    // For now, just announce navigation
    this.announceToScreenReader(`Navigerer ${direction > 0 ? 'høyre' : 'venstre'}`)
  }

  announceCurrentDataPoint() {
    // This would announce the currently focused data point
    this.announceToScreenReader('Gjeldende datapunkt')
  }

  getChartDescription() {
    const descriptions = {
      healthcare_radar: `Radar diagram som viser helseindikatorer for ${this.cityValue || 'Norge'}`,
      geographic_norway: `Kart over Norge med data for ${this.cityValue || 'alle fylker'}`,
      time_series: `Tidserie diagram som viser utvikling over tid`,
      bar_chart: `Stolpediagram som sammenligner verdier`,
      pie_chart: `Sektordiagram som viser prosentvis fordeling`
    }
    
    return descriptions[this.typeValue] || 'Interaktivt diagram med helsedata'
  }

  createAccessibilityDescription() {
    if (!this.hasAccessibilityTarget) return
    
    const description = this.generateDataDescription()
    this.accessibilityTarget.innerHTML = `
      <div class="sr-only" aria-live="polite">
        <h3>Diagrambeskrivelse</h3>
        <p>${this.getChartDescription()}</p>
        <div id="chart-data-description">${description}</div>
        <p>Bruk piltaster for å navigere, Enter for detaljer, Escape for å tilbakestille.</p>
      </div>
    `
  }

  generateDataDescription() {
    // Generate text description of the data for screen readers
    if (this.typeValue === 'pie_chart') {
      return this.generatePieDescription()
    } else if (this.typeValue === 'bar_chart') {
      return this.generateBarDescription()
    } else if (this.typeValue === 'time_series') {
      return this.generateTimeSeriesDescription()
    }
    
    return 'Datavisualisering med interaktive elementer.'
  }

  generatePieDescription() {
    const data = this.dataValue.data || []
    const total = data.reduce((sum, item) => sum + item.value, 0)
    
    return data.map(item => {
      const percentage = Math.round((item.value / total) * 100)
      return `${item.name}: ${this.formatNorwegianNumber(item.value)} (${percentage}%)`
    }).join(', ')
  }

  generateBarDescription() {
    const series = this.dataValue.series?.[0]?.data || []
    const categories = this.dataValue.categories || []
    
    return categories.map((category, index) => {
      const value = series[index] || 0
      return `${category}: ${this.formatNorwegianNumber(value)}`
    }).join(', ')
  }

  generateTimeSeriesDescription() {
    const series = this.dataValue.series || []
    return `Tidserie med ${series.length} datasett over tidsperioden`
  }

  updateAccessibilityDescription() {
    if (this.hasAccessibilityTarget) {
      const description = this.generateDataDescription()
      const descriptionElement = this.accessibilityTarget.querySelector('#chart-data-description')
      if (descriptionElement) {
        descriptionElement.innerHTML = description
      }
    }
  }

  updateChart() {
    if (!this.chart) return
    
    const options = this.buildChartOptions()
    this.chart.setOption(options, true)
    this.updateAccessibilityDescription()
  }

  destroyChart() {
    if (this.chart) {
      this.chart.dispose()
      this.chart = null
    }
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = 'block'
    }
    this.containerTarget.style.opacity = '0.5'
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = 'none'
    }
    this.containerTarget.style.opacity = '1'
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = `Feil ved lasting av diagram: ${message}`
      this.errorTarget.style.display = 'block'
    }
    console.error('Chart error:', message)
  }

  downloadImage(dataURL, filename) {
    const link = document.createElement('a')
    link.download = filename
    link.href = dataURL
    link.click()
  }

  announceToScreenReader(message) {
    if (window.HealthcarePlatform) {
      window.HealthcarePlatform.announceToScreenReader(message)
    }
  }

  deepMerge(target, source) {
    const result = { ...target }
    
    for (const key in source) {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        result[key] = this.deepMerge(result[key] || {}, source[key])
      } else {
        result[key] = source[key]
      }
    }
    
    return result
  }
}