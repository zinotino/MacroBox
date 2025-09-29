#!/usr/bin/env python3
"""
MacroMaster Timeline Slider Dashboard
Interactive timeline slider with pandas and plotly for unified data exploration
"""
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import numpy as np
import sys
import os
import webbrowser
from datetime import datetime, timedelta
import argparse
import json

class MacroMasterTimelineSlider:
    def __init__(self, csv_path):
        self.csv_path = csv_path
        self.df = self.load_and_clean_data()

        # Execution type colors for consistency
        self.execution_type_colors = {
            'macro': '#3498db',        # Blue for macros
            'json_profile': '#e74c3c'  # Red for JSON profiles
        }

    def load_and_clean_data(self):
        """Load and optimize MacroMaster CSV data with timeline focus and robust error handling"""
        try:
            if not os.path.exists(self.csv_path):
                print(f"CSV file not found: {self.csv_path}")
                return pd.DataFrame()

            # Read CSV with flexible parsing and better error handling
            df = pd.read_csv(self.csv_path, parse_dates=['timestamp'], on_bad_lines='skip', encoding='utf-8')

            if df.empty:
                print("No data found in CSV")
                return pd.DataFrame()

            # Check for required columns
            required_cols = ['timestamp', 'execution_type', 'total_boxes', 'execution_time_ms']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                print(f"Missing required columns: {missing_cols}")
                return pd.DataFrame()

            # Keep only rows with essential data
            df = df.dropna(subset=['timestamp', 'execution_type', 'total_boxes', 'execution_time_ms'])

            if df.empty:
                print("No valid data found after cleaning")
                return pd.DataFrame()

            # Clean data types with better error handling
            df['execution_time_ms'] = pd.to_numeric(df['execution_time_ms'], errors='coerce')
            df['total_boxes'] = pd.to_numeric(df['total_boxes'], errors='coerce')

            # Remove rows with invalid numeric data
            df = df.dropna(subset=['execution_time_ms', 'total_boxes'])

            # Filter out invalid values
            df = df[df['execution_time_ms'] > 0]
            df = df[df['total_boxes'] >= 0]

            if df.empty:
                print("No valid data found after filtering invalid values")
                return pd.DataFrame()

            # Fill missing fields with appropriate defaults
            df['session_id'] = df['session_id'].fillna('unknown_session')
            df['username'] = df['username'].fillna('unknown_user')
            df['degradation_assignments'] = df['degradation_assignments'].fillna('none')
            df['severity_level'] = df['severity_level'].fillna('none')
            df['canvas_mode'] = df['canvas_mode'].fillna('wide')
            df['button_key'] = df['button_key'].fillna('unknown')
            df['layer'] = pd.to_numeric(df['layer'], errors='coerce').fillna(1)

            # Parse timestamp column to datetime
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
            df = df.dropna(subset=['timestamp'])

            # Add timeline analysis columns
            df['date'] = df['timestamp'].dt.date
            df['hour'] = df['timestamp'].dt.hour
            df['execution_time_s'] = df['execution_time_ms'] / 1000
            df['boxes_per_second'] = df['total_boxes'] / df['execution_time_s']
            df['boxes_per_second'] = df['boxes_per_second'].replace([float('inf'), -float('inf')], 0)

            # Add degradation count columns if not present
            degradation_types = ['smudge', 'glare', 'clear', 'splashes', 'partial_blockage', 'full_blockage',
                                'haze', 'rain', 'snow', 'combined', 'light_flare', 'frost', 'debris',
                                'sun_glare', 'water_drops', 'fog', 'dust', 'ice']
            for degradation in degradation_types:
                col_name = f'{degradation}_count'
                if col_name not in df.columns:
                    df[col_name] = 0

            # Parse degradation assignments into count columns
            for idx, row in df.iterrows():
                if pd.notna(row['degradation_assignments']) and row['degradation_assignments'] != '':
                    assignments = str(row['degradation_assignments']).lower().split(',')
                    for assignment in assignments:
                        assignment = assignment.strip()
                        if assignment in degradation_types:
                            df.loc[idx, f'{assignment}_count'] = df.loc[idx, f'{assignment}_count'] + 1

            # Sort by timestamp for timeline
            df = df.sort_values('timestamp').reset_index(drop=True)

            print(f"Loaded {len(df)} MacroMaster execution records for timeline analysis")
            return df

        except Exception as e:
            print(f"Error loading MacroMaster data: {e}")
            import traceback
            traceback.print_exc()
            return pd.DataFrame()

    def create_timeline_slider_dashboard(self):
        """Create professional MacroMaster degradation analytics dashboard with 6 degradation visualizations"""

        if self.df.empty:
            self.create_empty_dashboard()
            return

        # Create 3x3 layout with macro combination focus and streamlined stats
        fig = make_subplots(
            rows=3, cols=3,
            subplot_titles=[
                '🎯 Macro Degradation Counts', '📊 JSON Degradation Counts', '🔄 Degradation Combinations',
                '📦 Total Boxes Over Time', '📦 Total Boxes Analysis', '⏱️ Time Performance Analysis',
                '📋 Key Metrics', '📈 Performance Summary', '🎯 Degradation Summary'
            ],
            specs=[
                [{"type": "bar"}, {"type": "bar"}, {"type": "bar"}],
                [{"type": "scatter"}, {"type": "bar"}, {"type": "scatter"}],
                [{"type": "table"}, {"type": "table"}, {"type": "table"}]
            ],
            vertical_spacing=0.12,
            horizontal_spacing=0.08,
            row_heights=[0.25, 0.25, 0.5]  # Bottom row taller for detailed tables
        )

        # Row 1: Macro degradation counts, JSON degradation counts, degradation combinations
        self.add_macro_degradation_counts_bar(fig, row=1, col=1)
        self.add_json_degradation_counts_bar(fig, row=1, col=2)
        self.add_degradation_combinations_bar(fig, row=1, col=3)

        # Row 2: Total boxes over time, boxes analysis, time performance
        self.add_total_boxes_over_time_scatter(fig, row=2, col=1)
        self.add_total_boxes_analysis_bar(fig, row=2, col=2)
        self.add_time_performance_scatter(fig, row=2, col=3)

        # Row 3: Streamlined key stats tables
        self.add_key_metrics_table(fig, row=3, col=1)
        self.add_performance_summary_table(fig, row=3, col=2)
        self.add_degradation_summary_table(fig, row=3, col=3)

        # Professional layout with enhanced visual design for degradation focus
        fig.update_layout(
            title={
                'text': "🎯 MacroMaster Degradation Analytics Dashboard",
                'x': 0.5,
                'xanchor': 'center',
                'font': {'size': 32, 'color': '#1f2937', 'family': 'Segoe UI, sans-serif'}
            },
            height=1400,
            width=1900,
            template="plotly_white",
            font={'family': 'Segoe UI, sans-serif', 'size': 11},
            margin=dict(l=60, r=60, t=140, b=60),
            showlegend=False,
            paper_bgcolor='#fafafa',
            plot_bgcolor='#ffffff'
        )

        # Update subplot axes for new 3x3 macro-focused layout
        # Total boxes over time gets date axes, time performance gets numeric axes
        fig.update_xaxes(type="date", row=2, col=1)  # Total boxes over time scatter
        fig.update_xaxes(type="linear", row=2, col=3)  # Time performance scatter

        # Save and display in organized structure
        output_dir = os.path.join(os.path.dirname(__file__), "output")
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, "macromaster_timeline_slider.html")

        # Add auto-refresh JavaScript for real-time updates
        auto_refresh_script = """
        <script>
        // Auto-refresh functionality for real-time statistics
        let refreshInterval = 30000; // 30 seconds
        let isRefreshing = false;

        function refreshDashboard() {
            if (isRefreshing) return;
            isRefreshing = true;

            console.log('Refreshing MacroMaster dashboard...');

            // Show refresh indicator
            const indicator = document.createElement('div');
            indicator.id = 'refresh-indicator';
            indicator.style.cssText = `
                position: fixed; top: 10px; right: 10px; z-index: 9999;
                background: #3498db; color: white; padding: 8px 16px;
                border-radius: 4px; font-family: 'Segoe UI', sans-serif;
                box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            `;
            indicator.textContent = '🔄 Refreshing data...';
            document.body.appendChild(indicator);

            // Reload the page to get fresh data
            setTimeout(() => {
                location.reload();
            }, 1000);
        }

        // Set up auto-refresh
        setInterval(refreshDashboard, refreshInterval);

        // Add manual refresh button
        function addRefreshButton() {
            const button = document.createElement('button');
            button.id = 'manual-refresh';
            button.style.cssText = `
                position: fixed; top: 10px; left: 10px; z-index: 9999;
                background: #2ecc71; color: white; border: none;
                padding: 8px 16px; border-radius: 4px; cursor: pointer;
                font-family: 'Segoe UI', sans-serif; font-size: 14px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            `;
            button.textContent = '🔄 Refresh Now';
            button.onclick = refreshDashboard;
            document.body.appendChild(button);
        }

        // Add status indicator
        function addStatusIndicator() {
            const status = document.createElement('div');
            status.id = 'live-status';
            status.style.cssText = `
                position: fixed; bottom: 10px; right: 10px; z-index: 9999;
                background: #27ae60; color: white; padding: 6px 12px;
                border-radius: 20px; font-family: 'Segoe UI', sans-serif;
                font-size: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            `;
            status.innerHTML = '<span style="margin-right: 6px;">🟢</span>Live Updates Active';
            document.body.appendChild(status);
        }

        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', function() {
            addRefreshButton();
            addStatusIndicator();
            console.log('MacroMaster real-time dashboard initialized');
        });
        </script>
        """

        # Write HTML with auto-refresh capability
        fig.write_html(output_file, auto_open=False, include_plotlyjs='cdn',
                      config={'displayModeBar': True, 'responsive': True})

        # Add auto-refresh script to the HTML file
        with open(output_file, 'r', encoding='utf-8') as f:
            html_content = f.read()

        # Insert the script before the closing body tag
        html_content = html_content.replace('</body>', auto_refresh_script + '\n</body>')

        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)

        print(f"MacroMaster Analytics Dashboard saved as: {output_file}")
        print("✅ Real-time auto-refresh enabled (30-second intervals)")

        # Simple and reliable browser launch for Windows
        try:
            abs_path = os.path.abspath(output_file)
            print(f"Dashboard created successfully: {abs_path}")
            print("Opening dashboard in browser...")

            # Create a simple batch file for reliable launching
            batch_file = os.path.join(os.path.dirname(output_file), "open_dashboard.bat")
            with open(batch_file, 'w') as f:
                f.write(f'@echo off\nstart "" "{abs_path}"\n')

            # Use os.startfile for Windows - most reliable method
            try:
                os.startfile(abs_path)
                print("Dashboard opened successfully in default browser!")
            except Exception as startfile_error:
                # Fallback to subprocess with proper Windows handling
                try:
                    import subprocess
                    # Use shell=True and properly quote the batch file path
                    subprocess.run(f'"{batch_file}"', shell=True, check=False)
                    print("Dashboard launch initiated via batch file.")
                except Exception as subprocess_error:
                    print(f"Batch file launch failed: {subprocess_error}")

            print("If the browser doesn't open automatically:")
            print(f"  Double-click this file: {batch_file}")
            print("  Or manually open: {abs_path}")

        except Exception as e:
            print(f"Browser launch failed: {e}")
            print(f"Please manually open: {os.path.abspath(output_file)}")

        # Save timeline metrics
        self.save_timeline_metrics()

    def add_user_actions_overview(self, fig, row, col):
        """Comprehensive overview of all user actions in MacroMaster"""
        if self.df is None or len(self.df) == 0:
            fig.add_annotation(
                text="No User Actions Recorded",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=16, color='#6b7280')
            )
            return

        # Count different types of user actions
        total_executions = len(self.df)
        macro_executions = len(self.df[self.df['execution_type'] == 'macro'])
        json_executions = len(self.df[self.df['execution_type'] == 'json_profile'])
        clear_executions = len(self.df[self.df['degradation_assignments'] == 'clear'])

        # Calculate degradation applications using CSV count fields for accuracy
        total_degradations = (
            self.df['smudge_count'].sum() +
            self.df['glare_count'].sum() +
            self.df['splashes_count'].sum() +
            self.df['partial_blockage_count'].sum() +
            self.df['full_blockage_count'].sum() +
            self.df['light_flare_count'].sum() +
            self.df['rain_count'].sum() +
            self.df['haze_count'].sum() +
            self.df['snow_count'].sum()
        )

        # Create action breakdown
        action_counts = {
            'Macro Executions': macro_executions,
            'JSON Profile Executions': json_executions,
            'Clear Degradations': clear_executions,
            'Degradation Applications': total_degradations
        }

        # Professional color scheme
        action_colors = ['#3498db', '#e74c3c', '#2ecc71', '#f39c12']

        fig.add_trace(
            go.Pie(
                labels=list(action_counts.keys()),
                values=list(action_counts.values()),
                name="User Actions",
                marker_colors=action_colors,
                textinfo='label+value+percent',
                textfont_size=13,
                textfont_color='white',
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>%{percent}<br><i>Total Actions: " + str(total_executions) + "</i><extra></extra>",
                pull=[0.05, 0.05, 0.05, 0.05]  # Slight pull for visual separation
            ),
            row=row, col=col
        )

        # Add center annotation with total
        fig.add_annotation(
            text=f"<b>{total_executions}</b><br><span style='font-size:12px;color:#666'>Total Actions</span>",
            xref="x domain", yref="y domain",
            x=0.5, y=0.5,
            showarrow=False,
            font=dict(size=18, color='#1f2937')
        )

    def _create_degradation_pie_chart(self, fig, row, col, execution_type=None, title_suffix=""):
        """Unified function to create degradation pie charts"""
        if self.df.empty:
            self._add_empty_annotation(fig, row, col, "No Degradation Data")
            return

        # Filter data by execution type if specified
        df_filtered = self.df if execution_type is None else self.df[self.df['execution_type'] == execution_type]

        if df_filtered.empty:
            self._add_empty_annotation(fig, row, col, f"No {execution_type.title() if execution_type else 'Data'}")
            return

        # Calculate total degradation applications
        total_degradations = (
            df_filtered['smudge_count'].sum() + df_filtered['glare_count'].sum() +
            df_filtered['splashes_count'].sum() + df_filtered['partial_blockage_count'].sum() +
            df_filtered['full_blockage_count'].sum() + df_filtered['light_flare_count'].sum() +
            df_filtered['rain_count'].sum() + df_filtered['haze_count'].sum() +
            df_filtered['snow_count'].sum()
        )

        clear_count = df_filtered['clear_count'].sum()
        total_boxes = df_filtered['total_boxes'].sum()

        # Create degradation vs clear breakdown
        degradation_data = {
            'Degradation Applications': int(total_degradations),
            'Clear Executions': int(clear_count)
        }

        colors = ['#ef4444', '#10b981']  # Red for degradation, green for clear
        trace_name = f"{execution_type.title() if execution_type else 'Overall'} Degradation Overview{title_suffix}"

        fig.add_trace(
            go.Pie(
                labels=list(degradation_data.keys()),
                values=list(degradation_data.values()),
                name=trace_name,
                marker_colors=colors,
                textinfo='label+value+percent',
                textfont_size=14,
                textfont_color='white',
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>%{percent}<br><i>Total: " + str(int(total_boxes)) + " boxes</i><extra></extra>",
                pull=[0.1, 0]  # Pull degradation slice
            ),
            row=row, col=col
        )

    def add_degradation_pie_chart(self, fig, row, col):
        """Pie chart showing overall degradation distribution"""
        self._create_degradation_pie_chart(fig, row, col)

    def add_degradation_bar_chart(self, fig, row, col):
        """Bar chart showing individual degradation type counts"""
        if self.df.empty:
            fig.add_annotation(
                text="No Degradation Data",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=14, color='#6b7280')
            )
            return

        # Collect all degradation applications with accurate counts
        degradation_totals = {
            'smudge': int(self.df['smudge_count'].sum()),
            'glare': int(self.df['glare_count'].sum()),
            'splashes': int(self.df['splashes_count'].sum()),
            'partial_blockage': int(self.df['partial_blockage_count'].sum()),
            'full_blockage': int(self.df['full_blockage_count'].sum()),
            'light_flare': int(self.df['light_flare_count'].sum()),
            'rain': int(self.df['rain_count'].sum()),
            'haze': int(self.df['haze_count'].sum()),
            'snow': int(self.df['snow_count'].sum())
        }

        # Filter out zero counts and sort by frequency
        active_degradations = {k: v for k, v in degradation_totals.items() if v > 0}
        sorted_degradations = sorted(active_degradations.items(), key=lambda x: x[1], reverse=True)

        if not sorted_degradations:
            fig.add_annotation(
                text="No Degradation Applications",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=14, color='#6b7280')
            )
            return

        labels, values = zip(*sorted_degradations)
        labels = [str(label).replace('_', ' ').title() for label in labels]
        values = list(values)

        # Professional color mapping for degradations
        degradation_colors = {
            'Smudge': '#f59e0b', 'Glare': '#ef4444', 'Splashes': '#8b5cf6',
            'Partial Blockage': '#dc2626', 'Full Blockage': '#991b1b',
            'Light Flare': '#f97316', 'Rain': '#ec4899', 'Haze': '#06b6d4', 'Snow': '#64748b'
        }

        colors = [degradation_colors.get(label, '#6b7280') for label in labels]

        fig.add_trace(
            go.Bar(
                x=labels,
                y=values,
                name="Degradation Types",
                marker_color=colors,
                text=values,
                texttemplate='%{text}',
                textposition='outside',
                textfont=dict(size=12, color='white'),
                hovertemplate="<b>%{x}</b><br>Applications: %{y}<br><i>Most frequent degradation types</i><extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(
            title_text="Degradation Type",
            tickangle=45,
            row=row, col=col
        )
        fig.update_yaxes(title_text="Total Applications", row=row, col=col)

    def add_performance_degradation_scatter(self, fig, row, col):
        """Scatter plot showing performance vs degradation intensity"""
        if self.df.empty:
            return

        # Calculate degradation intensity per execution
        self.df['degradation_intensity'] = (
            self.df['smudge_count'] + self.df['glare_count'] + self.df['splashes_count'] +
            self.df['partial_blockage_count'] + self.df['full_blockage_count'] +
            self.df['light_flare_count'] + self.df['rain_count'] + self.df['haze_count'] + self.df['snow_count']
        )

        # Color by execution type
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['degradation_intensity'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=np.clip(self.df['total_boxes'], 8, 20),
                    opacity=0.7,
                    line=dict(width=1, color='white')
                ),
                name='Performance vs Degradation',
                hovertemplate="<b>Degradation Intensity:</b> %{x}<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Boxes:</b> %{marker.size}<br><b>Type:</b> %{customdata}<extra></extra>",
                customdata=self.df['execution_type']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Degradation Intensity", row=row, col=col)
        fig.update_yaxes(title_text="Performance (boxes/sec)", row=row, col=col)

    def add_degradation_trends_timeline(self, fig, row, col):
        """Timeline showing degradation trends over time"""
        if self.df.empty:
            return

        # Calculate rolling degradation totals
        df_sorted = self.df.sort_values('timestamp').copy()
        df_sorted['rolling_degradations'] = (
            df_sorted['smudge_count'] + df_sorted['glare_count'] + df_sorted['splashes_count'] +
            df_sorted['partial_blockage_count'] + df_sorted['full_blockage_count'] +
            df_sorted['light_flare_count'] + df_sorted['rain_count'] + df_sorted['haze_count'] + df_sorted['snow_count']
        ).rolling(window=5, min_periods=1).mean()

        fig.add_trace(
            go.Scatter(
                x=df_sorted['timestamp'],
                y=df_sorted['rolling_degradations'],
                mode='lines+markers',
                name='Degradation Trend',
                line=dict(color='#e74c3c', width=3),
                marker=dict(size=6, color='#e74c3c'),
                hovertemplate="<b>%{x}</b><br>Avg Degradations: %{y:.1f}<br><i>5-execution rolling average</i><extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Degradation Intensity", row=row, col=col)

    def add_degradation_patterns_heatmap(self, fig, row, col):
        """Heatmap showing degradation patterns by hour and type"""
        if self.df.empty:
            return

        # Create hour-by-degradation matrix
        degradation_types = ['smudge', 'glare', 'splashes', 'partial_blockage', 'full_blockage', 'light_flare', 'rain', 'haze', 'snow']
        hourly_patterns = []

        for hour in range(24):
            hour_data = self.df[self.df['hour'] == hour]
            if not hour_data.empty:
                hour_totals = [hour_data[f'{deg}_count'].sum() for deg in degradation_types]
                hourly_patterns.append(hour_totals)
            else:
                hourly_patterns.append([0] * len(degradation_types))

        # Only show hours with data
        hours_with_data = [i for i, totals in enumerate(hourly_patterns) if sum(totals) > 0]
        if not hours_with_data:
            fig.add_annotation(
                text="No Hourly Degradation Patterns",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        # Create heatmap data
        z_data = [hourly_patterns[h] for h in hours_with_data]
        x_labels = [f"{h}:00" for h in hours_with_data]
        y_labels = [deg.replace('_', ' ').title() for deg in degradation_types]

        fig.add_trace(
            go.Heatmap(
                z=z_data,
                x=x_labels,
                y=y_labels,
                name="Degradation Patterns",
                colorscale='Reds',
                hovertemplate="<b>Hour:</b> %{x}<br><b>Degradation:</b> %{y}<br><b>Count:</b> %{z}<extra></extra>",
                showscale=True
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Hour of Day", row=row, col=col)
        fig.update_yaxes(title_text="Degradation Type", row=row, col=col)

    def add_macro_degradation_types_bar(self, fig, row, col):
        """Bar chart showing macro degradation types"""
        if self.df.empty:
            return

        # Filter for macro executions only
        macro_df = self.df[self.df['execution_type'] == 'macro']

        if macro_df.empty:
            fig.add_annotation(
                text="No Macro Executions",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        # Collect macro degradation applications
        macro_degradations = {
            'smudge': int(macro_df['smudge_count'].sum()),
            'glare': int(macro_df['glare_count'].sum()),
            'splashes': int(macro_df['splashes_count'].sum()),
            'partial_blockage': int(macro_df['partial_blockage_count'].sum()),
            'full_blockage': int(macro_df['full_blockage_count'].sum()),
            'light_flare': int(macro_df['light_flare_count'].sum()),
            'rain': int(macro_df['rain_count'].sum()),
            'haze': int(macro_df['haze_count'].sum()),
            'snow': int(macro_df['snow_count'].sum())
        }

        # Filter out zero counts and sort
        active_degradations = {k: v for k, v in macro_degradations.items() if v > 0}
        sorted_degradations = sorted(active_degradations.items(), key=lambda x: x[1], reverse=True)

        if not sorted_degradations:
            fig.add_annotation(
                text="No Macro Degradations",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        labels, values = zip(*sorted_degradations)
        labels = [str(label).replace('_', ' ').title() for label in labels]

        # Professional color mapping
        degradation_colors = {
            'Smudge': '#f59e0b', 'Glare': '#ef4444', 'Splashes': '#8b5cf6',
            'Partial Blockage': '#dc2626', 'Full Blockage': '#991b1b',
            'Light Flare': '#f97316', 'Rain': '#ec4899', 'Haze': '#06b6d4', 'Snow': '#64748b'
        }

        colors = [degradation_colors.get(label, '#6b7280') for label in labels]

        fig.add_trace(
            go.Bar(
                x=labels,
                y=values,
                name="Macro Degradations",
                marker_color=colors,
                text=values,
                texttemplate='%{text}',
                textposition='outside',
                textfont=dict(size=10, color='white'),
                hovertemplate="<b>%{x}</b><br>Macro Applications: %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Degradation Type", tickangle=45, row=row, col=col)
        fig.update_yaxes(title_text="Macro Applications", row=row, col=col)

    def add_macro_degradation_pie(self, fig, row, col):
        """Pie chart showing macro degradation distribution"""
        if self.df.empty:
            return

        # Filter for macro executions only
        macro_df = self.df[self.df['execution_type'] == 'macro']

        if macro_df.empty:
            fig.add_annotation(
                text="No Macro Executions",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        # Calculate macro degradation vs clear
        total_macro_degradations = (
            macro_df['smudge_count'].sum() + macro_df['glare_count'].sum() +
            macro_df['splashes_count'].sum() + macro_df['partial_blockage_count'].sum() +
            macro_df['full_blockage_count'].sum() + macro_df['light_flare_count'].sum() +
            macro_df['rain_count'].sum() + macro_df['haze_count'].sum() +
            macro_df['snow_count'].sum()
        )

        macro_clear = macro_df['clear_count'].sum()
        total_macro_boxes = macro_df['total_boxes'].sum()

        macro_data = {
            'Macro Degradations': int(total_macro_degradations),
            'Macro Clear': int(macro_clear)
        }

        colors = ['#ef4444', '#10b981']  # Red for degradation, green for clear

        fig.add_trace(
            go.Pie(
                labels=list(macro_data.keys()),
                values=list(macro_data.values()),
                name="Macro Degradation Overview",
                marker_colors=colors,
                textinfo='label+value+percent',
                textfont_size=12,
                textfont_color='white',
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>%{percent}<br><i>Total Macro Boxes: " + str(int(total_macro_boxes)) + "</i><extra></extra>",
                pull=[0.1, 0]  # Pull degradation slice
            ),
            row=row, col=col
        )

    def add_json_clear_applications_bar(self, fig, row, col):
        """Bar chart showing JSON degradations + clear applications"""
        if self.df.empty:
            return

        # Filter for JSON profile executions
        json_df = self.df[self.df['execution_type'] == 'json_profile']

        if json_df.empty:
            fig.add_annotation(
                text="No JSON Executions",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        # Collect JSON degradation applications
        json_degradations = {
            'smudge': int(json_df['smudge_count'].sum()),
            'glare': int(json_df['glare_count'].sum()),
            'splashes': int(json_df['splashes_count'].sum()),
            'partial_blockage': int(json_df['partial_blockage_count'].sum()),
            'full_blockage': int(json_df['full_blockage_count'].sum()),
            'light_flare': int(json_df['light_flare_count'].sum()),
            'rain': int(json_df['rain_count'].sum()),
            'haze': int(json_df['haze_count'].sum()),
            'snow': int(json_df['snow_count'].sum()),
            'clear': int(json_df['clear_count'].sum())
        }

        # Filter out zero counts and sort
        active_degradations = {k: v for k, v in json_degradations.items() if v > 0}
        sorted_degradations = sorted(active_degradations.items(), key=lambda x: x[1], reverse=True)

        if not sorted_degradations:
            fig.add_annotation(
                text="No JSON Degradations",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        labels, values = zip(*sorted_degradations)
        labels = [str(label).replace('_', ' ').title() for label in labels]

        # Color mapping - clear in green, degradations in blue/red
        degradation_colors = {
            'Smudge': '#f59e0b', 'Glare': '#ef4444', 'Splashes': '#8b5cf6',
            'Partial Blockage': '#dc2626', 'Full Blockage': '#991b1b',
            'Light Flare': '#f97316', 'Rain': '#ec4899', 'Haze': '#06b6d4',
            'Snow': '#64748b', 'Clear': '#10b981'
        }

        colors = [degradation_colors.get(label, '#6b7280') for label in labels]

        fig.add_trace(
            go.Bar(
                x=labels,
                y=values,
                name="JSON + Clear Applications",
                marker_color=colors,
                text=values,
                texttemplate='%{text}',
                textposition='outside',
                textfont=dict(size=10, color='white'),
                hovertemplate="<b>%{x}</b><br>JSON Applications: %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="JSON Degradation Type", tickangle=45, row=row, col=col)
        fig.update_yaxes(title_text="JSON Applications", row=row, col=col)

    def add_degradation_combinations_bar(self, fig, row, col):
        """Bar chart showing degradation combinations across types"""
        if self.df.empty:
            return

        # Analyze degradation patterns across both execution types
        degradation_by_type = self.df.groupby(['execution_type', 'degradation_assignments']).size().reset_index(name='count')
        degradation_by_type = degradation_by_type[degradation_by_type['degradation_assignments'] != 'none']
        degradation_by_type = degradation_by_type[degradation_by_type['degradation_assignments'] != '']

        if degradation_by_type.empty:
            fig.add_annotation(
                text="No Degradation Combinations",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        # Create grouped bar chart
        for exec_type in degradation_by_type['execution_type'].unique():
            type_data = degradation_by_type[degradation_by_type['execution_type'] == exec_type]
            color = self.execution_type_colors.get(exec_type, '#95a5a6')

            fig.add_trace(
                go.Bar(
                    x=type_data['degradation_assignments'],
                    y=type_data['count'],
                    name=exec_type.title(),
                    marker_color=color,
                    hovertemplate=f"<b>%{{x}}</b><br>{exec_type}: %{{y}}<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Degradation Combination", tickangle=45, row=row, col=col)
        fig.update_yaxes(title_text="Count", row=row, col=col)

    def add_total_boxes_analysis_bar(self, fig, row, col):
        """Bar chart showing total boxes analysis by button"""
        if self.df.empty:
            return

        # Group by button and calculate total boxes
        button_boxes = self.df.groupby('button_key')['total_boxes'].sum().reset_index()
        button_boxes = button_boxes.sort_values('total_boxes', ascending=True)

        if button_boxes.empty:
            fig.add_annotation(
                text="No Box Data",
                xref="paper", yref="paper",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#6b7280')
            )
            return

        fig.add_trace(
            go.Bar(
                y=button_boxes['button_key'],
                x=button_boxes['total_boxes'],
                orientation='h',
                name='Total Boxes',
                marker_color='#3498db',
                text=button_boxes['total_boxes'],
                texttemplate='%{text}',
                textposition='inside',
                textfont=dict(size=10, color='white'),
                hovertemplate="<b>Button %{y}</b><br>Total Boxes: %{x}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Total Boxes Processed", row=row, col=col)
        fig.update_yaxes(title_text="Button", row=row, col=col)

    def add_time_performance_scatter(self, fig, row, col):
        """Scatter plot showing time vs performance analysis"""
        if self.df.empty:
            return

        # Color by execution type
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['execution_time_ms'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=np.clip(self.df['total_boxes'], 8, 20),
                    opacity=0.7,
                    line=dict(width=1, color='white')
                ),
                name='Time vs Performance',
                hovertemplate="<b>Time:</b> %{x}ms<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Boxes:</b> %{marker.size}<br><b>Type:</b> %{customdata}<extra></extra>",
                customdata=self.df['execution_type']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Execution Time (ms)", row=row, col=col)
        fig.update_yaxes(title_text="Performance (boxes/sec)", row=row, col=col)

    def add_core_metrics_table(self, fig, row, col):
        """Core metrics table with essential statistics"""
        if self.df.empty:
            return

        # Calculate core metrics
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())
        macro_executions = len(self.df[self.df['execution_type'] == 'macro'])
        json_executions = len(self.df[self.df['execution_type'] == 'json_profile'])
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600

        core_data = {
            'Core Metric': [
                'Total Executions',
                'Total Boxes',
                'Macro Executions',
                'JSON Executions',
                'Session Duration (hrs)',
                'Boxes per Hour',
                'Executions per Hour',
                'Average Boxes/Execution',
                'Start Time',
                'End Time',
                'Unique Buttons',
                'Data Records'
            ],
            'Value': [
                f"{total_executions:,}",
                f"{total_boxes:,}",
                f"{macro_executions:,}",
                f"{json_executions:,}",
                f"{session_duration:.2f}",
                f"{total_boxes/session_duration:.0f}" if session_duration > 0 else "0",
                f"{total_executions/session_duration:.1f}" if session_duration > 0 else "0",
                f"{total_boxes/total_executions:.1f}",
                self.df['timestamp'].min().strftime('%H:%M:%S'),
                self.df['timestamp'].max().strftime('%H:%M:%S'),
                f"{self.df['button_key'].nunique()}",
                f"{len(self.df)}"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['📊 Core Metrics', '📈 Values'],
                    fill_color='#1f2937',
                    font_color='white',
                    font_size=10,
                    align='center',
                    height=25
                ),
                cells=dict(
                    values=[core_data['Core Metric'], core_data['Value']],
                    fill_color=[['#f8f9fa', '#ffffff'] * 6],
                    font_size=9,
                    align=['left', 'right'],
                    height=20
                )
            ),
            row=row, col=col
        )

    def add_performance_stats_table(self, fig, row, col):
        """Performance statistics table"""
        if self.df.empty:
            return

        # Calculate performance metrics
        avg_time = self.df['execution_time_ms'].mean()
        min_time = self.df['execution_time_ms'].min()
        max_time = self.df['execution_time_ms'].max()
        avg_speed = self.df['boxes_per_second'].mean()
        min_speed = self.df['boxes_per_second'].min()
        max_speed = self.df['boxes_per_second'].max()

        # Button performance
        button_performance = self.df.groupby('button_key')['boxes_per_second'].mean()
        fastest_button = button_performance.idxmax() if not button_performance.empty else "N/A"
        slowest_button = button_performance.idxmin() if not button_performance.empty else "N/A"

        performance_data = {
            'Performance Metric': [
                'Avg Execution Time (ms)',
                'Min Execution Time (ms)',
                'Max Execution Time (ms)',
                'Avg Speed (boxes/sec)',
                'Min Speed (boxes/sec)',
                'Max Speed (boxes/sec)',
                'Fastest Button',
                'Slowest Button',
                'Speed Variance',
                'Time Variance',
                'Efficiency Score',
                'Performance Rating'
            ],
            'Value': [
                f"{avg_time:.0f}",
                f"{min_time:.0f}",
                f"{max_time:.0f}",
                f"{avg_speed:.2f}",
                f"{min_speed:.2f}",
                f"{max_speed:.2f}",
                fastest_button,
                slowest_button,
                f"{self.df['boxes_per_second'].std():.2f}",
                f"{self.df['execution_time_ms'].std():.0f}",
                f"{(avg_speed / max_speed * 100):.1f}%" if max_speed > 0 else "0%",
                "Excellent" if avg_speed > 3 else "Good" if avg_speed > 2 else "Needs Improvement"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['⚡ Performance Stats', '📊 Values'],
                    fill_color='#059669',
                    font_color='white',
                    font_size=10,
                    align='center',
                    height=25
                ),
                cells=dict(
                    values=[performance_data['Performance Metric'], performance_data['Value']],
                    fill_color=[['#ecfdf5', '#f0fdf4'] * 6],
                    font_size=9,
                    align=['left', 'right'],
                    height=20
                )
            ),
            row=row, col=col
        )

    def _create_degradation_bar_chart(self, fig, row, col, execution_type=None, title_suffix=""):
        """Unified function to create degradation bar charts for any execution type"""
        if self.df.empty:
            self._add_empty_annotation(fig, row, col, f"No {execution_type.title() if execution_type else 'Data'} Executions")
            return

        # Filter data by execution type if specified
        df_filtered = self.df if execution_type is None else self.df[self.df['execution_type'] == execution_type]

        if df_filtered.empty:
            self._add_empty_annotation(fig, row, col, f"No {execution_type.title() if execution_type else 'Data'} Executions")
            return

        # Count each degradation type
        degradation_counts = {
            'smudge': int(df_filtered['smudge_count'].sum()),
            'glare': int(df_filtered['glare_count'].sum()),
            'splashes': int(df_filtered['splashes_count'].sum()),
            'partial_blockage': int(df_filtered['partial_blockage_count'].sum()),
            'full_blockage': int(df_filtered['full_blockage_count'].sum()),
            'light_flare': int(df_filtered['light_flare_count'].sum()),
            'rain': int(df_filtered['rain_count'].sum()),
            'haze': int(df_filtered['haze_count'].sum()),
            'snow': int(df_filtered['snow_count'].sum())
        }

        # Filter out zero counts and sort by frequency
        active_degradations = {k: v for k, v in degradation_counts.items() if v > 0}
        sorted_degradations = sorted(active_degradations.items(), key=lambda x: x[1], reverse=True)

        if not sorted_degradations:
            self._add_empty_annotation(fig, row, col, f"No {execution_type.title() if execution_type else 'Data'} Degradations")
            return

        labels, values = zip(*sorted_degradations)
        labels = [str(label).replace('_', ' ').title() for label in labels]

        # Professional color mapping for degradations
        degradation_colors = {
            'Smudge': '#f59e0b', 'Glare': '#ef4444', 'Splashes': '#8b5cf6',
            'Partial Blockage': '#dc2626', 'Full Blockage': '#991b1b',
            'Light Flare': '#f97316', 'Rain': '#ec4899', 'Haze': '#06b6d4', 'Snow': '#64748b'
        }

        colors = [degradation_colors.get(label, '#6b7280') for label in labels]
        trace_name = f"{execution_type.title() if execution_type else 'Overall'} Degradation Counts{title_suffix}"

        fig.add_trace(
            go.Bar(
                x=labels,
                y=values,
                name=trace_name,
                marker_color=colors,
                text=values,
                texttemplate='%{text}',
                textposition='outside',
                textfont=dict(size=10, color='white'),
                hovertemplate=f"<b>%{{x}}</b><br>{execution_type.title() if execution_type else 'Overall'} Applications: %{{y}}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Degradation Type", tickangle=45, row=row, col=col)
        y_title = f"{execution_type.title() if execution_type else 'Overall'} Applications"
        fig.update_yaxes(title_text=y_title, row=row, col=col)

    def _add_empty_annotation(self, fig, row, col, text):
        """Helper to add empty state annotations"""
        fig.add_annotation(
            text=text,
            xref="paper", yref="paper",
            x=0.5, y=0.5,
            showarrow=False,
            font=dict(size=12, color='#6b7280')
        )

    def add_macro_degradation_counts_bar(self, fig, row, col):
        """Simple count of degradations applied in macro executions"""
        self._create_degradation_bar_chart(fig, row, col, 'macro')

    def add_json_degradation_counts_bar(self, fig, row, col):
        """Simple count of degradations applied with JSON system"""
        self._create_degradation_bar_chart(fig, row, col, 'json_profile')

    def add_total_boxes_over_time_scatter(self, fig, row, col):
        """Total boxes over time function"""
        if self.df.empty:
            return

        # Sort by timestamp for proper time series
        df_sorted = self.df.sort_values('timestamp').copy()

        # Calculate cumulative boxes over time
        df_sorted['cumulative_boxes'] = df_sorted['total_boxes'].cumsum()

        # Color by execution type
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in df_sorted['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=df_sorted['timestamp'],
                y=df_sorted['cumulative_boxes'],
                mode='lines+markers',
                name='Total Boxes Over Time',
                line=dict(color='#3498db', width=3),
                marker=dict(
                    size=8,
                    color=colors,
                    opacity=0.8,
                    line=dict(width=1, color='white')
                ),
                hovertemplate="<b>%{x}</b><br>Cumulative Boxes: %{y:,}<br>Type: %{customdata}<extra></extra>",
                customdata=df_sorted['execution_type']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Boxes", row=row, col=col)

    def add_key_metrics_table(self, fig, row, col):
        """Streamlined key metrics table with most relevant stats"""
        if self.df.empty:
            return

        # Calculate key metrics only
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600
        avg_speed = self.df['boxes_per_second'].mean()
        total_degradations = sum([
            self.df['smudge_count'].sum(),
            self.df['glare_count'].sum(),
            self.df['splashes_count'].sum(),
            self.df['partial_blockage_count'].sum(),
            self.df['full_blockage_count'].sum(),
            self.df['light_flare_count'].sum(),
            self.df['rain_count'].sum(),
            self.df['haze_count'].sum(),
            self.df['snow_count'].sum()
        ])

        key_data = {
            'Key Metric': [
                'Total Executions',
                'Total Boxes',
                'Session Hours',
                'Avg Speed (boxes/sec)',
                'Boxes per Hour',
                'Total Degradations',
                'Degradation Rate (%)',
                'Macro Executions',
                'JSON Executions',
                'Most Used Button'
            ],
            'Value': [
                f"{total_executions:,}",
                f"{total_boxes:,}",
                f"{session_duration:.1f}",
                f"{avg_speed:.2f}",
                f"{total_boxes/session_duration:.0f}" if session_duration > 0 else "0",
                f"{total_degradations:,}",
                f"{(total_degradations/total_boxes*100):.1f}%" if total_boxes > 0 else "0%",
                f"{len(self.df[self.df['execution_type']=='macro']):,}",
                f"{len(self.df[self.df['execution_type']=='json_profile']):,}",
                self.df['button_key'].value_counts().index[0] if not self.df.empty else "N/A"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['📊 Key Metrics', '📈 Values'],
                    fill_color='#1f2937',
                    font_color='white',
                    font_size=10,
                    align='center',
                    height=25
                ),
                cells=dict(
                    values=[key_data['Key Metric'], key_data['Value']],
                    fill_color=[['#f8f9fa', '#ffffff'] * 5],
                    font_size=9,
                    align=['left', 'right'],
                    height=20
                )
            ),
            row=row, col=col
        )

    def add_performance_summary_table(self, fig, row, col):
        """Performance summary table with key performance indicators"""
        if self.df.empty:
            return

        # Calculate performance metrics
        avg_time = self.df['execution_time_ms'].mean()
        avg_speed = self.df['boxes_per_second'].mean()
        fastest_time = self.df['execution_time_ms'].min()
        slowest_time = self.df['execution_time_ms'].max()
        speed_std = self.df['boxes_per_second'].std()

        performance_data = {
            'Performance Metric': [
                'Avg Execution Time (ms)',
                'Avg Speed (boxes/sec)',
                'Fastest Execution (ms)',
                'Slowest Execution (ms)',
                'Speed Consistency (std)',
                'Efficiency Rating',
                'Top Performing Button',
                'Performance Trend'
            ],
            'Value': [
                f"{avg_time:.0f}",
                f"{avg_speed:.2f}",
                f"{fastest_time:.0f}",
                f"{slowest_time:.0f}",
                f"{speed_std:.2f}",
                "High" if avg_speed > 3 else "Medium" if avg_speed > 2 else "Low",
                self.df.groupby('button_key')['boxes_per_second'].mean().idxmax() if not self.df.empty else "N/A",
                "Stable" if speed_std < 1 else "Variable"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['⚡ Performance Summary', '📊 Values'],
                    fill_color='#059669',
                    font_color='white',
                    font_size=10,
                    align='center',
                    height=25
                ),
                cells=dict(
                    values=[performance_data['Performance Metric'], performance_data['Value']],
                    fill_color=[['#ecfdf5', '#f0fdf4'] * 4],
                    font_size=9,
                    align=['left', 'right'],
                    height=20
                )
            ),
            row=row, col=col
        )

    def add_degradation_summary_table(self, fig, row, col):
        """Degradation summary table with key degradation insights"""
        if self.df.empty:
            return

        # Calculate degradation summary
        total_degradations = sum([
            self.df['smudge_count'].sum(),
            self.df['glare_count'].sum(),
            self.df['splashes_count'].sum(),
            self.df['partial_blockage_count'].sum(),
            self.df['full_blockage_count'].sum(),
            self.df['light_flare_count'].sum(),
            self.df['rain_count'].sum(),
            self.df['haze_count'].sum(),
            self.df['snow_count'].sum()
        ])

        clear_count = self.df['clear_count'].sum()
        total_boxes = int(self.df['total_boxes'].sum())

        # Most common degradation
        degradation_totals = {
            'smudge': self.df['smudge_count'].sum(),
            'glare': self.df['glare_count'].sum(),
            'splashes': self.df['splashes_count'].sum(),
            'partial_blockage': self.df['partial_blockage_count'].sum(),
            'full_blockage': self.df['full_blockage_count'].sum(),
            'light_flare': self.df['light_flare_count'].sum(),
            'rain': self.df['rain_count'].sum(),
            'haze': self.df['haze_count'].sum(),
            'snow': self.df['snow_count'].sum()
        }

        most_common = max(degradation_totals.items(), key=lambda x: x[1]) if any(degradation_totals.values()) else ("None", 0)

        degradation_data = {
            'Degradation Metric': [
                'Total Degradations',
                'Clear Executions',
                'Degradation Rate (%)',
                'Most Common Degradation',
                'Macro Degradations',
                'JSON Degradations',
                'Degradation Efficiency',
                'Quality Score'
            ],
            'Value': [
                f"{total_degradations:,}",
                f"{clear_count:,}",
                f"{(total_degradations/total_boxes*100):.1f}%" if total_boxes > 0 else "0%",
                f"{most_common[0].replace('_', ' ').title()} ({most_common[1]})",
                f"{self.df[self.df['execution_type']=='macro']['smudge_count'].sum() + self.df[self.df['execution_type']=='macro']['glare_count'].sum():,}",
                f"{self.df[self.df['execution_type']=='json_profile']['smudge_count'].sum() + self.df[self.df['execution_type']=='json_profile']['glare_count'].sum():,}",
                "High" if total_degradations > total_boxes * 0.1 else "Medium" if total_degradations > total_boxes * 0.05 else "Low",
                f"{(clear_count/total_boxes*100):.1f}%" if total_boxes > 0 else "0%"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🎯 Degradation Summary', '📊 Values'],
                    fill_color='#7c3aed',
                    font_color='white',
                    font_size=10,
                    align='center',
                    height=25
                ),
                cells=dict(
                    values=[degradation_data['Degradation Metric'], degradation_data['Value']],
                    fill_color=[['#faf5ff', '#f3e8ff'] * 4],
                    font_size=9,
                    align=['left', 'right'],
                    height=20
                )
            ),
            row=row, col=col
        )

    def _create_organized_raw_data_table(self, fig, row, col):
        """Well-organized raw data table with better categorization and readability"""
        if self.df.empty:
            self._add_empty_annotation(fig, row, col, "No Data Available")
            return

        # Calculate comprehensive statistics
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600

        # Performance metrics
        avg_speed = self.df['boxes_per_second'].mean()
        avg_time = self.df['execution_time_ms'].mean()
        boxes_per_hour = total_boxes / session_duration if session_duration > 0 else 0

        # Degradation statistics (only active ones)
        degradation_counts = {
            'smudge': int(self.df['smudge_count'].sum()),
            'glare': int(self.df['glare_count'].sum()),
            'splashes': int(self.df['splashes_count'].sum()),
            'partial_blockage': int(self.df['partial_blockage_count'].sum()),
            'full_blockage': int(self.df['full_blockage_count'].sum()),
            'light_flare': int(self.df['light_flare_count'].sum()),
            'rain': int(self.df['rain_count'].sum()),
            'haze': int(self.df['haze_count'].sum()),
            'snow': int(self.df['snow_count'].sum())
        }

        # Filter and sort active degradations
        active_degradations = {k: v for k, v in degradation_counts.items() if v > 0}
        sorted_degradations = sorted(active_degradations.items(), key=lambda x: x[1], reverse=True)

        # Execution type breakdown
        macro_count = len(self.df[self.df['execution_type'] == 'macro'])
        json_count = len(self.df[self.df['execution_type'] == 'json_profile'])

        # Create organized table data with better structure
        raw_data = {
            '📊 Session Overview': [
                'Total Executions',
                'Session Duration (hours)',
                'Macro Executions',
                'JSON Profile Executions',
                'Total Boxes Processed',
                'Boxes per Hour',
                'Average Speed (boxes/sec)',
                'Average Execution Time (ms)',
                'Data Records',
                'Unique Buttons Used',
                'Start Time',
                'End Time'
            ],
            '📈 Values': [
                f"{total_executions:,}",
                f"{session_duration:.2f}",
                f"{macro_count:,}",
                f"{json_count:,}",
                f"{total_boxes:,}",
                f"{boxes_per_hour:.0f}",
                f"{avg_speed:.2f}",
                f"{avg_time:.0f}",
                f"{len(self.df)}",
                f"{self.df['button_key'].nunique()}",
                self.df['timestamp'].min().strftime('%H:%M:%S'),
                self.df['timestamp'].max().strftime('%H:%M:%S')
            ],
            '🎯 Active Degradations': [
                label.replace('_', ' ').title() for label, count in sorted_degradations
            ] + [''] * (12 - len(sorted_degradations)),  # Pad to match length
            '🔢 Applications': [
                f"{count:,}" for label, count in sorted_degradations
            ] + [''] * (12 - len(sorted_degradations))   # Pad to match length
        }

        # Ensure all columns have the same length
        max_len = max(len(raw_data[col]) for col in raw_data.keys())
        for col in raw_data.keys():
            while len(raw_data[col]) < max_len:
                raw_data[col].append('')

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['📊 Session Overview', '📈 Values', '🎯 Active Degradations', '🔢 Applications'],
                    fill_color='#1f2937',
                    font_color='white',
                    font_size=12,
                    align='center',
                    height=30
                ),
                cells=dict(
                    values=[raw_data['📊 Session Overview'], raw_data['📈 Values'],
                           raw_data['🎯 Active Degradations'], raw_data['🔢 Applications']],
                    fill_color=[['#f8f9fa', '#ffffff'] * 6, ['#f8f9fa', '#ffffff'] * 6,
                              ['#fef3c7', '#fef9c3'] * 6, ['#fef3c7', '#fef9c3'] * 6],
                    font_size=11,
                    align=['left', 'right', 'left', 'right'],
                    height=25
                )
            ),
            row=row, col=col
        )

    def add_detailed_raw_stats_table(self, fig, row, col):
        """Comprehensive raw statistics table - now uses organized format"""
        self._create_organized_raw_data_table(fig, row, col)

    def add_json_profile_focused(self, fig, row, col):
        """JSON profile execution analysis"""
        json_df = self.df[self.df['execution_type'] == 'json_profile']

        if json_df.empty:
            fig.add_annotation(
                text="No JSON Profile Executions",
                xref="paper", yref="paper",
                x=0.835, y=0.85,
                showarrow=False,
                font=dict(size=14, color='#6b7280')
            )
            return

        json_degradation_counts = json_df['degradation_assignments'].value_counts()

        json_colors = {
            'clear': '#3b82f6',
            'light_flare': '#6366f1',
            'glare': '#8b5cf6',
            'smudge': '#a855f7',
            'haze': '#c084fc'
        }

        colors = [json_colors.get(deg, '#94a3b8') for deg in json_degradation_counts.index]

        fig.add_trace(
            go.Pie(
                labels=json_degradation_counts.index,
                values=json_degradation_counts.values,
                name="JSON Profile Status",
                marker_colors=colors,
                textinfo='label+value+percent',
                textfont_size=12,
                hovertemplate="<b>%{label}</b><br>JSON Count: %{value}<br>%{percent}<extra></extra>"
            ),
            row=row, col=col
        )

    def add_performance_timeline(self, fig, row, col):
        """Performance timeline showing speed and execution patterns over time"""
        if self.df.empty:
            return

        # Main performance line - boxes per second over time
        fig.add_trace(
            go.Scatter(
                x=self.df['timestamp'],
                y=self.df['boxes_per_second'],
                mode='lines+markers',
                name='Performance (boxes/sec)',
                line=dict(color='#3498db', width=3),
                marker=dict(size=8, color='#3498db', opacity=0.7),
                hovertemplate="<b>%{x}</b><br>Speed: %{y:.2f} boxes/sec<br>Execution Time: %{customdata}ms<extra></extra>",
                customdata=self.df['execution_time_ms']
            ),
            row=row, col=col
        )

        # Add execution time as secondary y-axis for context
        fig.add_trace(
            go.Scatter(
                x=self.df['timestamp'],
                y=self.df['execution_time_ms'],
                mode='lines',
                name='Execution Time (ms)',
                line=dict(color='#e74c3c', width=2, dash='dot'),
                yaxis='y2',
                hovertemplate="<b>%{x}</b><br>Execution Time: %{y}ms<extra></extra>"
            ),
            row=row, col=col
        )

        # Add performance zones as shapes instead of hrect
        if len(self.df) > 2:
            avg_performance = self.df['boxes_per_second'].mean()
            high_perf_threshold = avg_performance * 1.2
            low_perf_threshold = avg_performance * 0.8

            # High performance zone
            fig.add_shape(
                type="rect",
                x0=self.df['timestamp'].min(),
                x1=self.df['timestamp'].max(),
                y0=high_perf_threshold,
                y1=self.df['boxes_per_second'].max() + 1,
                fillcolor="#d4edda",
                opacity=0.3,
                line_width=0,
                xref=f"x{3*row + col}",
                yref=f"y{3*row + col}"
            )

            # Low performance zone
            fig.add_shape(
                type="rect",
                x0=self.df['timestamp'].min(),
                x1=self.df['timestamp'].max(),
                y0=self.df['boxes_per_second'].min() - 1,
                y1=low_perf_threshold,
                fillcolor="#f8d7da",
                opacity=0.3,
                line_width=0,
                xref=f"x{3*row + col}",
                yref=f"y{3*row + col}"
            )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Performance (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Execution Time (ms)", secondary_y=True, row=row, col=col)

    def add_button_efficiency_analysis(self, fig, row, col):
        """Button efficiency analysis showing performance metrics per button"""
        if self.df.empty:
            return

        # Calculate comprehensive button metrics
        button_stats = self.df.groupby('button_key').agg({
            'total_boxes': 'sum',
            'execution_time_ms': ['count', 'mean'],
            'boxes_per_second': 'mean'
        }).round(2)

        # Flatten column names
        button_stats.columns = ['total_boxes', 'execution_count', 'avg_time_ms', 'avg_speed']
        button_stats = button_stats.reset_index()

        # Sort by efficiency (boxes per second)
        button_stats = button_stats.sort_values('avg_speed', ascending=True)

        # Create color gradient based on performance
        max_speed = button_stats['avg_speed'].max()
        min_speed = button_stats['avg_speed'].min()
        speed_range = max_speed - min_speed if max_speed != min_speed else 1

        colors = []
        for speed in button_stats['avg_speed']:
            # Green to red gradient based on performance
            intensity = (speed - min_speed) / speed_range
            colors.append(f'rgb({int(255*(1-intensity))},{int(255*intensity)},100)')

        fig.add_trace(
            go.Bar(
                y=list(button_stats['button_key']),
                x=list(button_stats['avg_speed']),
                orientation='h',
                name='Button Efficiency',
                marker_color=list(colors),
                text=list(button_stats['execution_count']),
                texttemplate='%{text} exec<br>%{x:.1f} boxes/sec',
                textposition='inside',
                textfont=dict(size=10, color='white'),
                hovertemplate="<b>Button %{y}</b><br>Avg Speed: %{x:.2f} boxes/sec<br>Total Boxes: %{customdata}<br>Executions: %{text}<extra></extra>",
                customdata=list(button_stats['total_boxes'])
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Average Performance (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Button", row=row, col=col)

    def add_processing_efficiency_scatter(self, fig, row, col):
        """Processing efficiency analysis"""
        if self.df.empty:
            return

        colors = [self.execution_type_colors.get(t, '#6b7280') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['total_boxes'],
                y=self.df['execution_time_ms'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=8,
                    opacity=0.7
                ),
                text=self.df['execution_type'],
                hovertemplate="<b>%{text}</b><br>Boxes: %{x}<br>Time: %{y}ms<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Boxes Processed", row=row, col=col)
        fig.update_yaxes(title_text="Execution Time (ms)", row=row, col=col)

    def add_execution_summary_table(self, fig, row, col):
        """Execution summary data table"""
        if self.df.empty:
            return

        total_executions = len(self.df)
        macro_executions = len(self.df[self.df['execution_type'] == 'macro'])
        json_executions = len(self.df[self.df['execution_type'] == 'json_profile'])

        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600
        total_boxes = self.df['total_boxes'].sum()

        execution_data = {
            'Execution Summary': [
                'Total Executions',
                'Macro Executions',
                'JSON Profile Executions',
                'Macro Percentage',
                'JSON Percentage',
                'Session Duration (hours)',
                'Total Boxes Processed',
                'Executions per Hour',
                'Boxes per Hour',
                'Average Boxes per Execution',
                'Start Time',
                'End Time',
                'Data Range Days',
                'Unique Button Tools',
                'Export Timestamp'
            ],
            'Values': [
                f"{total_executions}",
                f"{macro_executions}",
                f"{json_executions}",
                f"{(macro_executions/total_executions*100):.1f}%",
                f"{(json_executions/total_executions*100):.1f}%",
                f"{session_duration:.2f}",
                f"{total_boxes:,}",
                f"{total_executions/session_duration:.1f}" if session_duration > 0 else "0",
                f"{total_boxes/session_duration:.0f}" if session_duration > 0 else "0",
                f"{total_boxes/total_executions:.1f}",
                f"{self.df['timestamp'].min().strftime('%Y-%m-%d %H:%M')}",
                f"{self.df['timestamp'].max().strftime('%Y-%m-%d %H:%M')}",
                f"{(self.df['timestamp'].max() - self.df['timestamp'].min()).days}",
                f"{self.df['button_key'].nunique()}",
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['Execution Summary Data', 'Raw Values'],
                    fill_color='#1f2937',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(execution_data.values()),
                    fill_color=['#f9fafb', '#ffffff'] * 8,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_performance_metrics_table(self, fig, row, col):
        """Performance metrics data table"""
        if self.df.empty:
            return

        avg_execution_time = self.df['execution_time_ms'].mean()
        min_execution_time = self.df['execution_time_ms'].min()
        max_execution_time = self.df['execution_time_ms'].max()
        std_execution_time = self.df['execution_time_ms'].std()

        avg_boxes_per_second = self.df['boxes_per_second'].mean()
        min_boxes_per_second = self.df['boxes_per_second'].min()
        max_boxes_per_second = self.df['boxes_per_second'].max()
        std_boxes_per_second = self.df['boxes_per_second'].std()

        performance_data = {
            'Performance Metrics': [
                'Average Execution Time (ms)',
                'Min Execution Time (ms)',
                'Max Execution Time (ms)',
                'Std Dev Execution Time',
                'Average Boxes per Second',
                'Min Boxes per Second',
                'Max Boxes per Second',
                'Std Dev Boxes per Second',
                'Fastest Button Tool',
                'Slowest Button Tool',
                'Most Used Button',
                'Least Used Button',
                'Performance Variance',
                'Efficiency Range',
                'Total Processing Time (sec)'
            ],
            'Raw Measurements': [
                f"{avg_execution_time:.0f}",
                f"{min_execution_time:.0f}",
                f"{max_execution_time:.0f}",
                f"{std_execution_time:.0f}",
                f"{avg_boxes_per_second:.3f}",
                f"{min_boxes_per_second:.3f}",
                f"{max_boxes_per_second:.3f}",
                f"{std_boxes_per_second:.3f}",
                f"{self.df.groupby('button_key')['boxes_per_second'].mean().idxmax()}",
                f"{self.df.groupby('button_key')['boxes_per_second'].mean().idxmin()}",
                f"{self.df['button_key'].value_counts().index[0]}",
                f"{self.df['button_key'].value_counts().index[-1]}",
                f"{(std_execution_time/avg_execution_time):.3f}",
                f"{min_boxes_per_second:.3f} - {max_boxes_per_second:.3f}",
                f"{self.df['execution_time_ms'].sum()/1000:.1f}"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['Performance Metrics Data', 'Raw Measurements'],
                    fill_color='#059669',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(performance_data.values()),
                    fill_color=['#f0fdf4', '#ffffff'] * 8,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_quality_metrics_table(self, fig, row, col):
        """Quality metrics table with accurate degradation tracking"""
        if self.df.empty:
            return

        # Calculate quality metrics using accurate CSV count fields
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())

        # Use CSV degradation count fields for accuracy
        clear_total = self.df['clear_count'].sum()
        smudge_total = self.df['smudge_count'].sum()
        glare_total = self.df['glare_count'].sum()
        splashes_total = self.df['splashes_count'].sum()
        partial_blockage_total = self.df['partial_blockage_count'].sum()
        full_blockage_total = self.df['full_blockage_count'].sum()
        light_flare_total = self.df['light_flare_count'].sum()
        rain_total = self.df['rain_count'].sum()
        haze_total = self.df['haze_count'].sum()
        snow_total = self.df['snow_count'].sum()

        # Calculate degradation totals
        total_degradations = (smudge_total + glare_total + splashes_total +
                            partial_blockage_total + full_blockage_total +
                            light_flare_total + rain_total + haze_total + snow_total)

        # Quality scores
        overall_quality = (clear_total / max(total_boxes, 1)) * 100

        # Performance metrics
        avg_speed = self.df['boxes_per_second'].mean()
        avg_time = self.df['execution_time_ms'].mean()

        quality_data = {
            '📊 Quality Metrics': [
                'Total Executions',
                'Total Boxes Processed',
                'Clear Degradation Count',
                'Total Degradation Applications',
                'Overall Quality Score (%)',
                'Average Speed (boxes/sec)',
                'Average Execution Time (ms)',
                'Most Common Degradation',
                'Data Accuracy Score (%)',
                'Session Integrity'
            ],
            '📈 Values': [
                f"{total_executions:,}",
                f"{total_boxes:,}",
                f"{clear_total:,}",
                f"{total_degradations:,}",
                f"{overall_quality:.1f}%",
                f"{avg_speed:.2f}",
                f"{avg_time:.0f}",
                self._get_most_common_degradation(),
                f"{self._calculate_data_accuracy():.1f}%",
                "High" if total_executions > 10 else "Building"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['📊 Quality Metrics', '📈 Values'],
                    fill_color='#059669',
                    font_color='white',
                    font_size=12,
                    align='center',
                    height=30
                ),
                cells=dict(
                    values=[list(quality_data['📊 Quality Metrics']), list(quality_data['📈 Values'])],
                    fill_color=[['#ecfdf5', '#f0fdf4'] * 5],
                    font_size=11,
                    align=['left', 'right'],
                    height=28
                )
            ),
            row=row, col=col
        )

    def _get_most_common_degradation(self):
        """Get the most common degradation type"""
        degradation_counts = {
            'smudge': self.df['smudge_count'].sum(),
            'glare': self.df['glare_count'].sum(),
            'splashes': self.df['splashes_count'].sum(),
            'partial_blockage': self.df['partial_blockage_count'].sum(),
            'full_blockage': self.df['full_blockage_count'].sum(),
            'light_flare': self.df['light_flare_count'].sum(),
            'rain': self.df['rain_count'].sum(),
            'haze': self.df['haze_count'].sum(),
            'snow': self.df['snow_count'].sum()
        }

        if all(count == 0 for count in degradation_counts.values()):
            return "None"

        return max(degradation_counts.items(), key=lambda x: x[1])[0]

    def _calculate_data_accuracy(self):
        """Calculate data accuracy score based on field completeness"""
        required_fields = ['timestamp', 'execution_type', 'total_boxes', 'execution_time_ms']
        completeness_scores = []

        for field in required_fields:
            if field in self.df.columns:
                non_null_ratio = self.df[field].notna().sum() / len(self.df)
                completeness_scores.append(non_null_ratio)

        return (sum(completeness_scores) / len(completeness_scores)) * 100 if completeness_scores else 0

    def add_timeline_explorer(self, fig, row, col):
        """Clean timeline with execution points and rate overlay"""
        if self.df.empty:
            return

        # Main execution points
        fig.add_trace(
            go.Scatter(
                x=self.df['timestamp'],
                y=self.df['total_boxes'],
                mode='markers',
                marker=dict(
                    size=12,
                    color=[self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']],
                    opacity=0.8,
                    line=dict(width=1, color='white')
                ),
                name='Executions',
                hovertemplate="<b>%{x}</b><br>Boxes: %{y}<br>Type: %{customdata}<br>Button: %{text}<extra></extra>",
                customdata=self.df['execution_type'],
                text=self.df['button_key']
            ),
            row=row, col=col
        )

        # Execution rate line
        if len(self.df) > 1:
            hourly_data = self.df.set_index('timestamp').resample('1h')['execution_time_ms'].count().reset_index()
            hourly_data = hourly_data[hourly_data['execution_time_ms'] > 0]

            if not hourly_data.empty:
                fig.add_trace(
                    go.Scatter(
                        x=hourly_data['timestamp'],
                        y=hourly_data['execution_time_ms'],
                        mode='lines',
                        name='Rate/Hour',
                        line=dict(color='#e74c3c', width=2),
                        yaxis='y2',
                        hovertemplate="<b>%{x}</b><br>%{y} executions/hour<extra></extra>"
                    ),
                    row=row, col=col
                )

        fig.update_yaxes(title_text="Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Rate", secondary_y=True, row=row, col=col)

    def add_macro_degradations(self, fig, row, col):
        """Pie chart showing macro degradation breakdown"""
        self._create_degradation_pie_chart(fig, row, col, 'macro')

    def add_json_degradations(self, fig, row, col):
        """Pie chart showing JSON degradation breakdown"""
        if self.df.empty:
            return

        # Filter for JSON profile executions with degradation data
        json_data = self.df[
            (self.df['execution_type'] == 'json_profile') &
            (self.df['degradation_assignments'].notna()) &
            (self.df['degradation_assignments'] != '') &
            (self.df['degradation_assignments'] != 'none')
        ]

        if json_data.empty:
            # Show clean state for JSON
            fig.add_trace(
                go.Pie(
                    labels=['Clean JSON Profiles'],
                    values=[len(self.df[self.df['execution_type'] == 'json_profile'])],
                    marker_colors=['#3498db'],
                    hole=0.4,
                    textinfo='label+value',
                    hovertemplate="<b>%{label}</b><br>Count: %{value}<extra></extra>"
                ),
                row=row, col=col
            )
        else:
            degradation_counts = json_data['degradation_assignments'].value_counts()
            colors = ['#e74c3c', '#c0392b', '#a93226', '#922b21'][:len(degradation_counts)]

            fig.add_trace(
                go.Pie(
                    labels=degradation_counts.index,
                    values=degradation_counts.values,
                    marker_colors=colors,
                    hole=0.4,
                    textinfo='label+value',
                    hovertemplate="<b>%{label}</b><br>Count: %{value}<br>%{percent}<extra></extra>"
                ),
                row=row, col=col
            )

    def add_execution_totals(self, fig, row, col):
        """Bar chart showing execution totals by type"""
        if self.df.empty:
            return

        execution_totals = self.df.groupby('execution_type').agg({
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).reset_index()

        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in execution_totals['execution_type']]

        fig.add_trace(
            go.Bar(
                x=[t.replace('_', ' ').title() for t in execution_totals['execution_type']],
                y=execution_totals['total_boxes'],
                name='Total Boxes',
                marker_color=colors,
                text=execution_totals['execution_time_ms'],
                texttemplate='%{text} executions',
                textposition='outside',
                hovertemplate="<b>%{x}</b><br>Total Boxes: %{y:,}<br>Executions: %{text}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_yaxes(title_text="Total Boxes", row=row, col=col)

    def add_speed_analysis(self, fig, row, col):
        """Scatter plot showing speed vs boxes relationship"""
        if self.df.empty:
            return

        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['total_boxes'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    size=10,
                    color=colors,
                    opacity=0.7,
                    line=dict(width=1, color='white')
                ),
                name='Speed vs Volume',
                hovertemplate="<b>Boxes:</b> %{x}<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Type:</b> %{customdata}<extra></extra>",
                customdata=self.df['execution_type']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)

    def add_speed_statistics(self, fig, row, col):
        """Scatter plot showing detailed speed analysis"""
        if self.df.empty:
            return

        # Color by execution type for clarity
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['execution_time_ms'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    size=12,
                    color=colors,
                    opacity=0.8,
                    line=dict(width=1, color='white')
                ),
                name='Speed vs Time',
                hovertemplate="<b>Time:</b> %{x}ms<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Boxes:</b> %{customdata}<extra></extra>",
                customdata=self.df['total_boxes']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Execution Time (ms)", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)

    def add_timeline_statistics(self, fig, row, col):
        """Histogram showing execution frequency over time periods"""
        if self.df.empty:
            return

        # Create hourly execution counts
        hourly_counts = self.df.groupby(self.df['timestamp'].dt.hour)['execution_time_ms'].count()

        fig.add_trace(
            go.Histogram(
                x=self.df['timestamp'].dt.hour,
                nbinsx=24,
                name='Hourly Distribution',
                marker_color='#3498db',
                opacity=0.7,
                hovertemplate="<b>Hour:</b> %{x}:00<br><b>Executions:</b> %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Hour of Day", row=row, col=col)
        fig.update_yaxes(title_text="Execution Count", row=row, col=col)

    def add_degradation_combinations(self, fig, row, col):
        """Bar chart showing degradation combinations across types"""
        if self.df.empty:
            return

        # Analyze degradation patterns across both execution types
        degradation_by_type = self.df.groupby(['execution_type', 'degradation_assignments']).size().reset_index(name='count')
        degradation_by_type = degradation_by_type[degradation_by_type['degradation_assignments'] != 'none']

        if degradation_by_type.empty:
            fig.add_annotation(
                text="No Degradation Combinations",
                x=0.5, y=0.5,
                showarrow=False,
                font=dict(size=12, color='#7f8c8d')
            )
            return

        # Create grouped bar chart
        for exec_type in degradation_by_type['execution_type'].unique():
            type_data = degradation_by_type[degradation_by_type['execution_type'] == exec_type]
            color = self.execution_type_colors.get(exec_type, '#95a5a6')

            fig.add_trace(
                go.Bar(
                    x=type_data['degradation_assignments'],
                    y=type_data['count'],
                    name=exec_type.title(),
                    marker_color=color,
                    hovertemplate=f"<b>%{{x}}</b><br>{exec_type}: %{{y}}<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Degradation Type", row=row, col=col)
        fig.update_yaxes(title_text="Count", row=row, col=col)

    def add_button_efficiency(self, fig, row, col):
        """Horizontal bar chart showing button efficiency metrics"""
        if self.df.empty:
            return

        button_stats = self.df.groupby('button_key').agg({
            'boxes_per_second': 'mean',
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).round(2).sort_values('boxes_per_second', ascending=True)

        fig.add_trace(
            go.Bar(
                y=button_stats.index,
                x=button_stats['boxes_per_second'],
                orientation='h',
                name='Button Efficiency',
                marker_color='#1abc9c',
                text=button_stats['total_boxes'],
                texttemplate='%{text} boxes',
                textposition='inside',
                hovertemplate="<b>Button %{y}</b><br>Avg Speed: %{x:.2f} boxes/sec<br>Total Boxes: %{text}<br>Uses: %{customdata}<extra></extra>",
                customdata=button_stats['execution_time_ms']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Average Speed (boxes/sec)", row=row, col=col)

    def add_execution_patterns(self, fig, row, col):
        """Scatter plot showing execution patterns and trends"""
        if self.df.empty:
            return

        # Sort by timestamp and add sequence numbers
        df_sorted = self.df.sort_values('timestamp').copy()
        df_sorted['sequence'] = range(1, len(df_sorted) + 1)

        # Color by execution type
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in df_sorted['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=df_sorted['sequence'],
                y=df_sorted['total_boxes'],
                mode='markers+lines',
                marker=dict(
                    size=8,
                    color=colors,
                    opacity=0.8,
                    line=dict(width=1, color='white')
                ),
                line=dict(color='#bdc3c7', width=1),
                name='Execution Pattern',
                hovertemplate="<b>Execution #%{x}</b><br>Boxes: %{y}<br>Type: %{customdata}<extra></extra>",
                customdata=df_sorted['execution_type']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Execution Sequence", row=row, col=col)
        fig.update_yaxes(title_text="Boxes", row=row, col=col)

    def add_raw_data_summary(self, fig, row, col):
        """Raw statistics table with no semantics"""
        if self.df.empty:
            return

        # Calculate raw numerical data only
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())
        macro_executions = len(self.df[self.df['execution_type'] == 'macro'])
        json_executions = len(self.df[self.df['execution_type'] == 'json_profile'])

        avg_execution_time = self.df['execution_time_ms'].mean()
        min_execution_time = self.df['execution_time_ms'].min()
        max_execution_time = self.df['execution_time_ms'].max()

        avg_speed = self.df['boxes_per_second'].mean()
        min_speed = self.df['boxes_per_second'].min()
        max_speed = self.df['boxes_per_second'].max()

        session_duration_minutes = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 60

        unique_buttons = len(self.df['button_key'].unique())

        raw_data = {
            'Raw Metric': [
                'Total Executions',
                'Total Boxes',
                'Macro Executions',
                'JSON Executions',
                'Avg Execution Time (ms)',
                'Min Execution Time (ms)',
                'Max Execution Time (ms)',
                'Avg Speed (boxes/sec)',
                'Min Speed (boxes/sec)',
                'Max Speed (boxes/sec)',
                'Session Duration (min)',
                'Unique Buttons Used'
            ],
            'Value': [
                f"{total_executions}",
                f"{total_boxes}",
                f"{macro_executions}",
                f"{json_executions}",
                f"{avg_execution_time:.1f}",
                f"{min_execution_time}",
                f"{max_execution_time}",
                f"{avg_speed:.2f}",
                f"{min_speed:.2f}",
                f"{max_speed:.2f}",
                f"{session_duration_minutes:.1f}",
                f"{unique_buttons}"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['Raw Data', 'Value'],
                    fill_color='#2c3e50',
                    font_color='white',
                    font_size=10,
                    align='center'
                ),
                cells=dict(
                    values=list(raw_data.values()),
                    fill_color='#ecf0f1',
                    font_size=9,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_time_statistics(self, fig, row, col):
        """Histogram showing execution time distribution"""
        if self.df.empty:
            return

        fig.add_trace(
            go.Histogram(
                x=self.df['execution_time_ms'],
                nbinsx=10,
                name='Time Distribution',
                marker_color='#9b59b6',
                opacity=0.7,
                hovertemplate="<b>Time Range:</b> %{x}ms<br><b>Count:</b> %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Execution Time (ms)", row=row, col=col)
        fig.update_yaxes(title_text="Frequency", row=row, col=col)

    def add_button_performance(self, fig, row, col):
        """Horizontal bar chart showing button performance"""
        if self.df.empty:
            return

        button_stats = self.df.groupby('button_key').agg({
            'total_boxes': 'sum',
            'boxes_per_second': 'mean',
            'execution_time_ms': 'count'
        }).round(2).sort_values('total_boxes', ascending=True)

        fig.add_trace(
            go.Bar(
                y=button_stats.index,
                x=button_stats['total_boxes'],
                orientation='h',
                name='Button Performance',
                marker_color='#1abc9c',
                text=button_stats['boxes_per_second'],
                texttemplate='%{text} boxes/sec',
                textposition='inside',
                hovertemplate="<b>Button %{y}</b><br>Total Boxes: %{x}<br>Avg Speed: %{text} boxes/sec<br>Uses: %{customdata}<extra></extra>",
                customdata=button_stats['execution_time_ms']
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)

    def add_activity_patterns(self, fig, row, col):
        """Scatter plot showing activity patterns over time"""
        if self.df.empty:
            return

        # Create activity intensity visualization
        fig.add_trace(
            go.Scatter(
                x=self.df['timestamp'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    size=np.clip(self.df['total_boxes']/3, 6, 20),
                    color=self.df['execution_time_ms'],
                    colorscale='Viridis',
                    opacity=0.7,
                    colorbar=dict(title="Time (ms)", x=1.02, len=0.5)
                ),
                name='Activity Patterns',
                hovertemplate="<b>%{x}</b><br>Speed: %{y:.2f} boxes/sec<br>Boxes: %{customdata}<extra></extra>",
                customdata=self.df['total_boxes']
            ),
            row=row, col=col
        )

        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)

    def add_session_summary(self, fig, row, col):
        """Summary table with key session metrics"""
        if self.df.empty:
            return

        # Calculate key metrics
        total_executions = len(self.df)
        total_boxes = int(self.df['total_boxes'].sum())
        avg_speed = self.df['boxes_per_second'].mean()
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600

        macro_count = len(self.df[self.df['execution_type'] == 'macro'])
        json_count = len(self.df[self.df['execution_type'] == 'json_profile'])

        summary_data = {
            'Metric': [
                'Total Executions',
                'Total Boxes',
                'Macro Executions',
                'JSON Profiles',
                'Average Speed',
                'Session Duration',
                'Boxes per Hour',
                'Peak Speed'
            ],
            'Value': [
                f"{total_executions:,}",
                f"{total_boxes:,}",
                f"{macro_count}",
                f"{json_count}",
                f"{avg_speed:.2f} boxes/sec",
                f"{session_duration:.2f} hours",
                f"{total_boxes/session_duration:.0f}" if session_duration > 0 else "0",
                f"{self.df['boxes_per_second'].max():.2f} boxes/sec"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['Session Metrics', 'Values'],
                    fill_color='#34495e',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(summary_data.values()),
                    fill_color='#ecf0f1',
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_execution_efficiency_analysis(self, fig, row, col):
        """Advanced execution efficiency analysis showing performance patterns"""
        if self.df.empty:
            return

        # Create efficiency bubble chart
        fig.add_trace(
            go.Scatter(
                x=self.df['execution_time_ms'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    size=np.clip(self.df['total_boxes'], 10, 30),
                    color=self.df['total_boxes'],
                    colorscale='Viridis',
                    opacity=0.7,
                    line=dict(width=1, color='white'),
                    showscale=True,
                    colorbar=dict(title="Total Boxes", x=1.02)
                ),
                name='Efficiency Analysis',
                hovertemplate="<b>Execution Time:</b> %{x}ms<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Total Boxes:</b> %{marker.size}<br><b>Button:</b> %{text}<extra></extra>",
                text=self.df['button_key']
            ),
            row=row, col=col
        )

        # Add efficiency target line (ideal performance)
        if len(self.df) > 1:
            max_speed = self.df['boxes_per_second'].quantile(0.9)
            time_range = [self.df['execution_time_ms'].min(), self.df['execution_time_ms'].max()]

            fig.add_trace(
                go.Scatter(
                    x=time_range,
                    y=[max_speed, max_speed],
                    mode='lines',
                    name='90th Percentile Speed',
                    line=dict(color='#e74c3c', width=2, dash='dot'),
                    yaxis='y2',
                    hovertemplate="Target Speed: %{y:.2f} boxes/sec<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Execution Time (ms)", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Target Performance", secondary_y=True, row=row, col=col)

    def add_speed_volume_correlation(self, fig, row, col):
        """Speed vs volume correlation analysis with trend analysis"""
        if self.df.empty:
            return

        # Main scatter plot with button differentiation
        button_colors = {}
        color_palette = ['#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6', '#1abc9c']

        for i, button in enumerate(self.df['button_key'].unique()):
            button_data = self.df[self.df['button_key'] == button]
            color = color_palette[i % len(color_palette)]
            button_colors[button] = color

            fig.add_trace(
                go.Scatter(
                    x=button_data['total_boxes'],
                    y=button_data['boxes_per_second'],
                    mode='markers',
                    marker=dict(
                        size=12,
                        color=color,
                        opacity=0.8,
                        line=dict(width=2, color='white')
                    ),
                    name=f'Button {button}',
                    hovertemplate=f"<b>Button {button}</b><br>Boxes: %{{x}}<br>Speed: %{{y:.2f}} boxes/sec<br>Time: %{{customdata}}ms<extra></extra>",
                    customdata=button_data['execution_time_ms']
                ),
                row=row, col=col
            )

        # Add correlation trend line
        if len(self.df) > 2:
            z = np.polyfit(self.df['total_boxes'], self.df['boxes_per_second'], 1)
            p = np.poly1d(z)
            x_trend = np.linspace(self.df['total_boxes'].min(), self.df['total_boxes'].max(), 100)

            fig.add_trace(
                go.Scatter(
                    x=x_trend,
                    y=p(x_trend),
                    mode='lines',
                    name='Correlation Trend',
                    line=dict(color='#34495e', width=3, dash='dash'),
                    yaxis='y2',
                    hovertemplate="Trend Line<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Trend", secondary_y=True, row=row, col=col)

    def add_activity_patterns_and_trends(self, fig, row, col):
        """Activity patterns showing when user is most productive"""
        if self.df.empty:
            return

        # Minute-by-minute activity heatmap data
        self.df['minute'] = self.df['timestamp'].dt.minute
        activity_matrix = self.df.groupby(['hour', 'minute']).agg({
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).reset_index()

        # Create activity intensity chart
        fig.add_trace(
            go.Scatter(
                x=self.df['timestamp'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    size=np.clip(self.df['total_boxes']/2, 8, 20),
                    color=self.df['execution_time_ms'],
                    colorscale='Plasma',
                    opacity=0.8,
                    line=dict(width=1, color='white')
                ),
                name='Activity Intensity',
                hovertemplate="<b>%{x}</b><br>Speed: %{y:.2f} boxes/sec<br>Boxes: %{marker.size}<br>Duration: %{marker.color}ms<extra></extra>"
            ),
            row=row, col=col
        )

        # Add productivity zones
        if len(self.df) > 3:
            productivity_avg = self.df['boxes_per_second'].mean()
            productivity_std = self.df['boxes_per_second'].std()

            high_productivity = productivity_avg + productivity_std
            low_productivity = productivity_avg - productivity_std

            time_range = [self.df['timestamp'].min(), self.df['timestamp'].max()]

            fig.add_trace(
                go.Scatter(
                    x=time_range,
                    y=[high_productivity, high_productivity],
                    mode='lines',
                    name='High Productivity Zone',
                    line=dict(color='#2ecc71', width=2, dash='dot'),
                    yaxis='y2'
                ),
                row=row, col=col
            )

            fig.add_trace(
                go.Scatter(
                    x=time_range,
                    y=[low_productivity, low_productivity],
                    mode='lines',
                    name='Low Productivity Zone',
                    line=dict(color='#e74c3c', width=2, dash='dot'),
                    yaxis='y2'
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Performance (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Productivity Zones", secondary_y=True, row=row, col=col)

    def add_cumulative_achievement_progress(self, fig, row, col):
        """Cumulative progress with velocity analysis"""
        if self.df.empty:
            return

        # Sort by timestamp for proper cumulative calculation
        df_sorted = self.df.sort_values('timestamp').copy()
        df_sorted['cumulative_boxes'] = df_sorted['total_boxes'].cumsum()
        df_sorted['cumulative_time'] = df_sorted['execution_time_ms'].cumsum() / 1000  # Convert to seconds

        # Main cumulative line
        fig.add_trace(
            go.Scatter(
                x=df_sorted['timestamp'],
                y=df_sorted['cumulative_boxes'],
                mode='lines+markers',
                name='Cumulative Boxes',
                line=dict(color='#3498db', width=4),
                marker=dict(size=8, color='#3498db'),
                fill='tonexty',
                hovertemplate="<b>%{x}</b><br>Total Boxes: %{y:,}<br>Execution #%{customdata}<extra></extra>",
                customdata=list(range(1, len(df_sorted) + 1))
            ),
            row=row, col=col
        )

        # Velocity (boxes per minute)
        if len(df_sorted) > 1:
            df_sorted['time_diff'] = df_sorted['timestamp'].diff().dt.total_seconds() / 60  # minutes
            df_sorted['velocity'] = df_sorted['total_boxes'] / df_sorted['time_diff'].fillna(1)

            # Rolling velocity average
            df_sorted['velocity_avg'] = df_sorted['velocity'].rolling(window=3, min_periods=1).mean()

            fig.add_trace(
                go.Scatter(
                    x=df_sorted['timestamp'],
                    y=df_sorted['velocity_avg'],
                    mode='lines',
                    name='Velocity (boxes/min)',
                    line=dict(color='#e74c3c', width=3),
                    yaxis='y2',
                    hovertemplate="<b>%{x}</b><br>Velocity: %{y:.1f} boxes/min<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Velocity (boxes/min)", secondary_y=True, row=row, col=col)

    def add_comprehensive_session_analytics(self, fig, row, col):
        """Comprehensive session analytics table with key metrics"""
        if self.df.empty:
            return

        # Calculate comprehensive metrics
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600
        total_boxes = int(self.df['total_boxes'].sum())
        total_executions = len(self.df)
        avg_speed = self.df['boxes_per_second'].mean()
        peak_speed = self.df['boxes_per_second'].max()
        efficiency_score = (avg_speed / peak_speed * 100) if peak_speed > 0 else 0

        # Button performance
        button_performance = self.df.groupby('button_key').agg({
            'boxes_per_second': 'mean',
            'total_boxes': 'sum'
        }).round(2)
        top_button = button_performance['boxes_per_second'].idxmax()

        # Time analysis
        boxes_per_hour = total_boxes / session_duration if session_duration > 0 else 0
        busiest_hour = self.df.groupby('hour')['total_boxes'].sum().idxmax()

        analytics_data = {
            'Metric Category': [
                'Session Overview',
                'Total Executions',
                'Total Boxes Processed',
                'Session Duration',
                'Performance Analysis',
                'Average Speed',
                'Peak Speed',
                'Efficiency Score',
                'Productivity Analysis',
                'Boxes per Hour',
                'Most Productive Hour',
                'Top Performing Button',
                'Performance Rating'
            ],
            'Value & Analysis': [
                f"{total_executions} executions across {session_duration:.2f} hours",
                f"{total_executions:,} executions",
                f"{total_boxes:,} boxes",
                f"{session_duration:.2f} hours",
                "Speed & Consistency Metrics",
                f"{avg_speed:.2f} boxes/sec",
                f"{peak_speed:.2f} boxes/sec",
                f"{efficiency_score:.1f}% of peak performance",
                "Workflow Optimization Insights",
                f"{boxes_per_hour:.0f} boxes/hour",
                f"{busiest_hour}:00 (most active)",
                f"Button {top_button} ({button_performance.loc[top_button, 'boxes_per_second']:.2f} boxes/sec)",
                "Excellent" if efficiency_score > 80 else "Good" if efficiency_score > 60 else "Needs Improvement"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['💻 Session Analytics', '📊 Results & Insights'],
                    fill_color='#2980b9',
                    font_color='white',
                    font_size=12,
                    align='center',
                    height=30
                ),
                cells=dict(
                    values=list(analytics_data.values()),
                    fill_color=[['#ecf0f1', '#f8f9fa'] * 7],
                    font_size=10,
                    align=['left', 'left'],
                    height=25
                )
            ),
            row=row, col=col
        )

    def add_performance_insights_and_recommendations(self, fig, row, col):
        """Performance insights with actionable recommendations"""
        if self.df.empty:
            return

        # Advanced performance analysis
        speed_cv = self.df['boxes_per_second'].std() / self.df['boxes_per_second'].mean() if self.df['boxes_per_second'].mean() > 0 else 0
        consistency_rating = "Highly Consistent" if speed_cv < 0.2 else "Moderately Consistent" if speed_cv < 0.4 else "Inconsistent"

        # Identify optimization opportunities
        slow_executions = len(self.df[self.df['execution_time_ms'] > self.df['execution_time_ms'].quantile(0.8)])
        optimization_target = f"{slow_executions} slow executions" if slow_executions > 0 else "No major bottlenecks"

        # Button efficiency analysis
        button_efficiency = self.df.groupby('button_key')['boxes_per_second'].mean()
        inefficient_buttons = button_efficiency[button_efficiency < button_efficiency.mean() - button_efficiency.std()]

        # Recommendations
        recommendations = []
        if speed_cv > 0.4:
            recommendations.append("Focus on consistent execution speed")
        if slow_executions > len(self.df) * 0.2:
            recommendations.append("Optimize workflow to reduce execution time")
        if len(inefficient_buttons) > 0:
            recommendations.append(f"Improve efficiency of buttons: {', '.join(inefficient_buttons.index)}")
        if len(recommendations) == 0:
            recommendations.append("Maintain current excellent performance")

        insights_data = {
            'Insight Category': [
                'Performance Consistency',
                'Speed Variation (CV)',
                'Optimization Target',
                'Workflow Efficiency',
                'Button Performance',
                'Session Quality',
                'Primary Recommendation',
                'Secondary Focus',
                'Next Action Item',
                'Performance Trend'
            ],
            'Assessment & Action': [
                consistency_rating,
                f"{speed_cv:.2f} (lower is better)",
                optimization_target,
                f"{len(self.df.groupby('button_key'))} buttons used effectively",
                f"Avg: {button_efficiency.mean():.2f} boxes/sec",
                "Productive session" if len(self.df) > 5 else "Short session",
                recommendations[0] if recommendations else "Maintain performance",
                recommendations[1] if len(recommendations) > 1 else "Continue current approach",
                "Analyze button-specific patterns" if len(self.df.groupby('button_key')) > 2 else "Increase activity volume",
                "Improving" if len(self.df) > 5 and self.df.tail(3)['boxes_per_second'].mean() > self.df.head(3)['boxes_per_second'].mean() else "Stable"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🔍 Performance Insights', '🎯 Recommendations'],
                    fill_color='#27ae60',
                    font_color='white',
                    font_size=12,
                    align='center',
                    height=30
                ),
                cells=dict(
                    values=list(insights_data.values()),
                    fill_color=[['#e8f5e8', '#f0f8f0'] * 5],
                    font_size=10,
                    align=['left', 'left'],
                    height=25
                )
            ),
            row=row, col=col
        )

    def add_speed_performance_analysis(self, fig, row, col):
        """Speed performance analysis without unnecessary colorbar"""
        if self.df.empty:
            return

        # Create speed vs boxes scatter
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['total_boxes'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=12,
                    opacity=0.8,
                    line=dict(width=2, color='white')
                ),
                name='Speed Analysis',
                text=self.df['execution_type'],
                hovertemplate="<b>Boxes:</b> %{x}<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Type:</b> %{text}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)

    def add_button_usage_patterns(self, fig, row, col):
        """Button usage patterns chart"""
        if self.df.empty:
            return

        # Group by button key
        button_stats = self.df.groupby('button_key').agg({
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).reset_index()

        button_stats = button_stats.sort_values('total_boxes', ascending=True)

        fig.add_trace(
            go.Bar(
                y=button_stats['button_key'],
                x=button_stats['total_boxes'],
                orientation='h',
                name="Button Usage",
                marker_color='#2ecc71',
                text=button_stats['execution_time_ms'],
                texttemplate='%{text} uses',
                textposition='inside',
                hovertemplate="<b>%{y}</b><br>Boxes: %{x}<br>Uses: %{text}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Button", row=row, col=col)

    def add_hourly_activity_distribution(self, fig, row, col):
        """Hourly activity distribution"""
        if self.df.empty:
            return

        hourly_activity = self.df.groupby('hour')['execution_time_ms'].count()

        fig.add_trace(
            go.Bar(
                x=hourly_activity.index,
                y=hourly_activity.values,
                name="Hourly Activity",
                marker_color='#3498db',
                hovertemplate="<b>Hour:</b> %{x}:00<br><b>Executions:</b> %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Hour of Day", row=row, col=col)
        fig.update_yaxes(title_text="Executions", row=row, col=col)

    def add_cumulative_progress_tracking(self, fig, row, col):
        """Cumulative progress tracking"""
        if self.df.empty:
            return

        # Calculate cumulative metrics
        df_sorted = self.df.sort_values('timestamp').copy()
        df_sorted['cumulative_boxes'] = df_sorted['total_boxes'].cumsum()
        df_sorted['cumulative_executions'] = range(1, len(df_sorted) + 1)

        fig.add_trace(
            go.Scatter(
                x=df_sorted['timestamp'],
                y=df_sorted['cumulative_boxes'],
                mode='lines+markers',
                name='Cumulative Boxes',
                line=dict(color='#9b59b6', width=3),
                marker=dict(size=6),
                hovertemplate="<b>%{x}</b><br>Total Boxes: %{y:,}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.add_trace(
            go.Scatter(
                x=df_sorted['timestamp'],
                y=df_sorted['cumulative_executions'],
                mode='lines',
                name='Cumulative Executions',
                line=dict(color='#34495e', width=2, dash='dash'),
                yaxis='y2',
                hovertemplate="<b>%{x}</b><br>Total Executions: %{y:,}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Executions", secondary_y=True, row=row, col=col)

    def add_execution_type_breakdown(self, fig, row, col):
        """Execution type breakdown pie chart"""
        if self.df.empty:
            return

        # Execution type breakdown
        type_counts = self.df['execution_type'].value_counts()
        colors = [self.execution_type_colors.get(exec_type, '#95a5a6') for exec_type in type_counts.index]

        fig.add_trace(
            go.Pie(
                labels=[t.title().replace('_', ' ') for t in type_counts.index],
                values=type_counts.values,
                name="Execution Types",
                marker_colors=colors,
                hole=0.3,
                textinfo='label+value+percent',
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>"
            ),
            row=row, col=col
        )

    def add_session_performance_summary(self, fig, row, col):
        """Session performance summary table"""
        if self.df.empty:
            return

        # Session duration
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600
        executions_per_hour = len(self.df) / session_duration if session_duration > 0 else 0
        boxes_per_hour = self.df['total_boxes'].sum() / session_duration if session_duration > 0 else 0

        # Performance metrics
        avg_speed = self.df['boxes_per_second'].mean()
        avg_execution_time = self.df['execution_time_ms'].mean()

        session_data = {
            'Session Metric': [
                'Session Duration',
                'Total Executions',
                'Total Boxes',
                'Executions/Hour',
                'Boxes/Hour',
                'Avg Speed',
                'Avg Execution Time',
                'Peak Activity Hour'
            ],
            'Value': [
                f"{session_duration:.2f} hours",
                f"{len(self.df)}",
                f"{self.df['total_boxes'].sum():,}",
                f"{executions_per_hour:.1f}/hr",
                f"{boxes_per_hour:.0f}/hr",
                f"{avg_speed:.2f} boxes/sec",
                f"{avg_execution_time:.0f}ms",
                f"{self.df.groupby('hour')['execution_time_ms'].count().idxmax()}:00"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['💻 Session Summary', '📊 Values'],
                    fill_color='#2ecc71',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(session_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_actionable_insights_table(self, fig, row, col):
        """Actionable insights and recommendations based on user behavior"""
        if self.df.empty:
            return

        # Calculate comprehensive insights
        total_executions = len(self.df)
        avg_speed = self.df['boxes_per_second'].mean()
        speed_std = self.df['boxes_per_second'].std()
        avg_time = self.df['execution_time_ms'].mean()

        # Button performance analysis
        button_performance = self.df.groupby('button_key')['boxes_per_second'].mean()
        fastest_button = button_performance.idxmax() if not button_performance.empty else "N/A"
        slowest_button = button_performance.idxmin() if not button_performance.empty else "N/A"

        # Degradation analysis
        total_degradations = sum([
            self.df['smudge_count'].sum(),
            self.df['glare_count'].sum(),
            self.df['splashes_count'].sum(),
            self.df['partial_blockage_count'].sum(),
            self.df['full_blockage_count'].sum(),
            self.df['light_flare_count'].sum(),
            self.df['rain_count'].sum(),
            self.df['haze_count'].sum(),
            self.df['snow_count'].sum()
        ])

        # Performance ratings
        speed_rating = "🚀 Excellent" if avg_speed > 3 else "✅ Good" if avg_speed > 2 else "⚠️ Needs Improvement"
        consistency_rating = "🎯 Consistent" if speed_std < 1 else "📊 Variable"
        activity_rating = "🔥 High Activity" if total_executions > 50 else "📈 Moderate Activity" if total_executions > 20 else "🌱 Building Activity"

        # Generate recommendations
        recommendations = []
        if speed_std > 1.5:
            recommendations.append("🎯 Focus on execution consistency")
        if avg_time > 3000:
            recommendations.append("⚡ Optimize workflow speed")
        if len(button_performance) > 5 and button_performance.std() > 0.5:
            recommendations.append(f"🎮 Improve button {slowest_button} efficiency")
        if total_degradations < total_executions * 0.1:
            recommendations.append("✨ Excellent degradation management")
        if len(recommendations) == 0:
            recommendations.append("🎉 Performance is optimal")

        insights_data = {
            '💡 Actionable Insights': [
                'Performance Rating',
                'Consistency Level',
                'Activity Level',
                'Top Performing Button',
                'Optimization Focus',
                'Average Speed',
                'Total Degradations',
                'Primary Recommendation',
                'Secondary Focus',
                'Next Steps'
            ],
            '🎯 Recommendations': [
                speed_rating,
                consistency_rating,
                activity_rating,
                f"Button {fastest_button}",
                f"Button {slowest_button} needs attention" if slowest_button != fastest_button else "All buttons performing well",
                f"{avg_speed:.2f} boxes/sec",
                f"{total_degradations} applications",
                recommendations[0] if recommendations else "Maintain current performance",
                recommendations[1] if len(recommendations) > 1 else "Continue monitoring",
                "📊 Analyze detailed patterns" if total_executions > 20 else "🔄 Generate more execution data"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['💡 Actionable Insights', '🎯 Recommendations'],
                    fill_color='#7c3aed',
                    font_color='white',
                    font_size=12,
                    align='center',
                    height=30
                ),
                cells=dict(
                    values=[list(insights_data['💡 Actionable Insights']), list(insights_data['🎯 Recommendations'])],
                    fill_color=[['#faf5ff', '#f3e8ff'] * 5],
                    font_size=11,
                    align=['left', 'left'],
                    height=28
                )
            ),
            row=row, col=col
        )

    def add_execution_rate_timeline(self, fig, row, col):
        """Execution rate analysis over time"""
        if self.df.empty:
            return

        # Calculate rolling averages
        hourly_data = self.df.set_index('timestamp').resample('1h').agg({
            'execution_time_ms': 'count',
            'total_boxes': 'sum'
        }).reset_index()

        # Calculate 6-hour rolling average
        hourly_data['rolling_avg'] = hourly_data['execution_time_ms'].rolling(window=6, min_periods=1).mean()

        fig.add_trace(
            go.Scatter(
                x=hourly_data['timestamp'],
                y=hourly_data['execution_time_ms'],
                mode='markers',
                name='Hourly Executions',
                marker=dict(color='#3498db', size=6, opacity=0.6),
                hovertemplate="<b>%{x}</b><br>Executions: %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.add_trace(
            go.Scatter(
                x=hourly_data['timestamp'],
                y=hourly_data['rolling_avg'],
                mode='lines',
                name='6h Rolling Average',
                line=dict(color='#e74c3c', width=3),
                hovertemplate="<b>%{x}</b><br>Avg: %{y:.1f}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Execution Rate", row=row, col=col)

    def add_speed_analysis_timeline(self, fig, row, col):
        """Speed analysis over time"""
        if self.df.empty:
            return

        # Calculate speed metrics over time
        hourly_speed = self.df.set_index('timestamp').resample('1h').agg({
            'boxes_per_second': 'mean',
            'execution_time_ms': 'mean'
        }).reset_index()

        hourly_speed = hourly_speed.dropna()

        # Plot speed trend
        fig.add_trace(
            go.Scatter(
                x=hourly_speed['timestamp'],
                y=hourly_speed['boxes_per_second'],
                mode='lines+markers',
                name='Speed (boxes/sec)',
                line=dict(color='#2ecc71', width=2),
                marker=dict(size=6),
                hovertemplate="<b>%{x}</b><br>Speed: %{y:.2f} boxes/sec<extra></extra>"
            ),
            row=row, col=col
        )

        # Add execution time as secondary y-axis
        fig.add_trace(
            go.Scatter(
                x=hourly_speed['timestamp'],
                y=hourly_speed['execution_time_ms'],
                mode='lines',
                name='Avg Execution Time',
                line=dict(color='#f39c12', width=2, dash='dot'),
                yaxis='y4',
                hovertemplate="<b>%{x}</b><br>Time: %{y:.0f}ms<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)
        fig.update_yaxes(title_text="Execution Time (ms)", secondary_y=True, row=row, col=col)

    def add_cumulative_timeline(self, fig, row, col):
        """Cumulative metrics over time"""
        if self.df.empty:
            return

        # Calculate cumulative metrics
        df_sorted = self.df.sort_values('timestamp').copy()
        df_sorted['cumulative_boxes'] = df_sorted['total_boxes'].cumsum()
        df_sorted['cumulative_executions'] = range(1, len(df_sorted) + 1)

        # Sample data for performance (every 10th point if large dataset)
        if len(df_sorted) > 1000:
            df_sample = df_sorted.iloc[::max(1, len(df_sorted)//1000)]
        else:
            df_sample = df_sorted

        fig.add_trace(
            go.Scatter(
                x=df_sample['timestamp'],
                y=df_sample['cumulative_boxes'],
                mode='lines',
                name='Cumulative Boxes',
                line=dict(color='#9b59b6', width=3),
                fill='tonexty',
                hovertemplate="<b>%{x}</b><br>Total Boxes: %{y:,}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.add_trace(
            go.Scatter(
                x=df_sample['timestamp'],
                y=df_sample['cumulative_executions'],
                mode='lines',
                name='Cumulative Executions',
                line=dict(color='#34495e', width=2),
                yaxis='y6',
                hovertemplate="<b>%{x}</b><br>Total Executions: %{y:,}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Cumulative Executions", secondary_y=True, row=row, col=col)

    def add_session_breakdown(self, fig, row, col):
        """Session breakdown pie chart"""
        if self.df.empty:
            return

        # Execution type breakdown
        type_counts = self.df['execution_type'].value_counts()
        colors = [self.execution_type_colors.get(exec_type, '#95a5a6') for exec_type in type_counts.index]

        fig.add_trace(
            go.Pie(
                labels=[t.title().replace('_', ' ') for t in type_counts.index],
                values=type_counts.values,
                name="Execution Types",
                marker_colors=colors,
                hole=0.3,
                textinfo='label+value+percent',
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>"
            ),
            row=row, col=col
        )

    def add_button_performance_timeline(self, fig, row, col):
        """Button performance over time"""
        if self.df.empty:
            return

        # Group by button and time
        button_timeline = self.df.groupby(['button_key', self.df['timestamp'].dt.floor('1h')]).agg({
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).reset_index()

        # Plot top buttons
        top_buttons = self.df.groupby('button_key')['total_boxes'].sum().nlargest(5).index

        for button in top_buttons:
            button_data = button_timeline[button_timeline['button_key'] == button]
            if not button_data.empty:
                fig.add_trace(
                    go.Scatter(
                        x=button_data['timestamp'],
                        y=button_data['total_boxes'],
                        mode='lines+markers',
                        name=f'Button {button}',
                        hovertemplate=f"<b>Button {button}</b><br>%{{x}}<br>Boxes: %{{y}}<extra></extra>"
                    ),
                    row=row, col=col
                )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Boxes", row=row, col=col)

    def add_hourly_activity_heatmap(self, fig, row, col):
        """Hourly activity breakdown"""
        if self.df.empty:
            return

        hourly_activity = self.df.groupby('hour')['execution_time_ms'].count()

        fig.add_trace(
            go.Bar(
                x=hourly_activity.index,
                y=hourly_activity.values,
                name="Hourly Activity",
                marker_color='#3498db',
                hovertemplate="<b>Hour:</b> %{x}:00<br><b>Executions:</b> %{y}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Hour of Day", row=row, col=col)
        fig.update_yaxes(title_text="Executions", row=row, col=col)

    def add_detailed_speed_metrics(self, fig, row, col):
        """Detailed speed analysis scatter"""
        if self.df.empty:
            return

        # Color by execution type
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in self.df['execution_type']]

        fig.add_trace(
            go.Scatter(
                x=self.df['total_boxes'],
                y=self.df['boxes_per_second'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=self.df['execution_time_ms']/50,  # Size by execution time
                    opacity=0.7,
                    line=dict(width=1, color='white')
                ),
                name="Speed Analysis",
                text=self.df['execution_type'],
                hovertemplate="<b>Boxes:</b> %{x}<br><b>Speed:</b> %{y:.2f} boxes/sec<br><b>Type:</b> %{text}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Speed (boxes/sec)", row=row, col=col)

    def add_performance_insights_chart(self, fig, row, col):
        """Performance insights over time"""
        if self.df.empty:
            return

        # Calculate performance metrics
        performance_data = self.df.copy()
        performance_data['efficiency'] = performance_data['total_boxes'] / performance_data['execution_time_ms'] * 1000

        fig.add_trace(
            go.Scatter(
                x=performance_data['timestamp'],
                y=performance_data['efficiency'],
                mode='markers',
                marker=dict(
                    color=performance_data['total_boxes'],
                    colorscale='Viridis',
                    size=8,
                    showscale=True,
                    colorbar=dict(title="Boxes")
                ),
                name="Efficiency",
                hovertemplate="<b>%{x}</b><br>Efficiency: %{y:.2f}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Efficiency (boxes/sec)", row=row, col=col)

    def add_speed_analysis_table(self, fig, row, col):
        """Detailed speed analysis table"""
        if self.df.empty:
            return

        # Calculate speed metrics
        avg_speed = self.df['boxes_per_second'].mean()
        median_speed = self.df['boxes_per_second'].median()
        max_speed = self.df['boxes_per_second'].max()
        min_speed = self.df['boxes_per_second'].min()
        speed_std = self.df['boxes_per_second'].std()

        # Speed percentiles
        p25_speed = self.df['boxes_per_second'].quantile(0.25)
        p75_speed = self.df['boxes_per_second'].quantile(0.75)
        p90_speed = self.df['boxes_per_second'].quantile(0.90)

        speed_data = {
            'Speed Metric': [
                'Average Speed',
                'Median Speed',
                'Maximum Speed',
                'Minimum Speed',
                'Standard Deviation',
                '25th Percentile',
                '75th Percentile',
                '90th Percentile'
            ],
            'Value (boxes/sec)': [
                f"{avg_speed:.2f}",
                f"{median_speed:.2f}",
                f"{max_speed:.2f}",
                f"{min_speed:.2f}",
                f"{speed_std:.2f}",
                f"{p25_speed:.2f}",
                f"{p75_speed:.2f}",
                f"{p90_speed:.2f}"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['⚡ Speed Analysis', '📊 Values'],
                    fill_color='#3498db',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(speed_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_timeline_analysis_table(self, fig, row, col):
        """Timeline analysis table"""
        if self.df.empty:
            return

        # Timeline metrics
        session_duration = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600
        executions_per_hour = len(self.df) / session_duration if session_duration > 0 else 0
        boxes_per_hour = self.df['total_boxes'].sum() / session_duration if session_duration > 0 else 0

        # Time distribution
        busiest_hour = self.df.groupby('hour')['execution_time_ms'].count().idxmax()
        peak_activity = self.df.groupby('hour')['execution_time_ms'].count().max()

        timeline_data = {
            'Timeline Metric': [
                'Session Duration',
                'Total Executions',
                'Executions/Hour',
                'Boxes/Hour',
                'Busiest Hour',
                'Peak Activity',
                'First Execution',
                'Last Execution'
            ],
            'Value': [
                f"{session_duration:.2f} hours",
                f"{len(self.df)}",
                f"{executions_per_hour:.1f}/hr",
                f"{boxes_per_hour:.0f}/hr",
                f"{busiest_hour}:00",
                f"{peak_activity} executions",
                self.df['timestamp'].min().strftime('%H:%M'),
                self.df['timestamp'].max().strftime('%H:%M')
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🕒 Timeline Analysis', '📈 Metrics'],
                    fill_color='#2ecc71',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(timeline_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def add_performance_summary_table(self, fig, row, col):
        """Performance summary table"""
        if self.df.empty:
            return

        # Performance summary
        total_boxes = int(self.df['total_boxes'].sum())
        avg_execution_time = self.df['execution_time_ms'].mean()
        fastest_execution = self.df['execution_time_ms'].min()
        slowest_execution = self.df['execution_time_ms'].max()

        # Efficiency metrics
        macro_count = len(self.df[self.df['execution_type'] == 'macro'])
        json_count = len(self.df[self.df['execution_type'] == 'json_profile'])
        efficiency_ratio = macro_count / len(self.df) * 100 if len(self.df) > 0 else 0

        performance_data = {
            'Performance Summary': [
                'Total Boxes Processed',
                'Average Execution Time',
                'Fastest Execution',
                'Slowest Execution',
                'Macro Executions',
                'JSON Executions',
                'Macro Efficiency %',
                'Overall Performance'
            ],
            'Results': [
                f"{total_boxes:,} boxes",
                f"{avg_execution_time:.0f}ms",
                f"{fastest_execution:.0f}ms",
                f"{slowest_execution:.0f}ms",
                f"{macro_count}",
                f"{json_count}",
                f"{efficiency_ratio:.1f}%",
                "Excellent" if avg_execution_time < 5000 else "Good" if avg_execution_time < 10000 else "Needs Optimization"
            ]
        }

        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🎯 Performance Summary', '📊 Results'],
                    fill_color='#e74c3c',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(performance_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )

    def create_empty_dashboard(self):
        """Create dashboard when no data is available"""
        fig = go.Figure()
        fig.add_annotation(
            text="No MacroMaster data available<br>Start using MacroMaster to generate timeline analytics!",
            xref="paper", yref="paper",
            x=0.5, y=0.5,
            showarrow=False,
            font=dict(size=18)
        )
        fig.update_layout(
            title="🎮 MacroMaster Timeline Slider - No Data",
            template="plotly_white",
            height=800
        )
        output_file = "macromaster_timeline_slider_empty.html"
        fig.write_html(output_file, auto_open=False)
        webbrowser.open(f"file://{os.path.abspath(output_file)}")
        print(f"Empty Timeline Slider dashboard created: {output_file}")

    def save_timeline_metrics(self):
        """Save timeline-focused metrics"""
        try:
            if self.df.empty:
                return

            # Calculate timeline-specific metrics
            total_executions = len(self.df)
            total_boxes = int(self.df['total_boxes'].sum())
            session_duration_hours = (self.df['timestamp'].max() - self.df['timestamp'].min()).total_seconds() / 3600

            # Rate analysis
            hourly_data = self.df.set_index('timestamp').resample('1h')['execution_time_ms'].count()
            peak_hour_executions = hourly_data.max()
            avg_hourly_executions = hourly_data.mean()

            # Speed analysis
            avg_speed = self.df['boxes_per_second'].mean()
            peak_speed = self.df['boxes_per_second'].max()

            # Timeline insights
            busiest_hour = self.df.groupby('hour')['execution_time_ms'].count().idxmax()
            busiest_day = self.df.groupby('date')['execution_time_ms'].count().idxmax()

            metrics = {
                "dashboard_type": "timeline_slider",
                "total_executions": total_executions,
                "total_boxes": total_boxes,
                "session_duration_hours": round(session_duration_hours, 2),
                "boxes_per_hour": round(total_boxes/session_duration_hours, 1) if session_duration_hours > 0 else 0,
                "peak_hour_executions": int(peak_hour_executions),
                "avg_hourly_executions": round(avg_hourly_executions, 1),
                "avg_speed_boxes_per_second": round(avg_speed, 2),
                "peak_speed_boxes_per_second": round(peak_speed, 2),
                "busiest_hour": int(busiest_hour),
                "busiest_day": str(busiest_day),
                "timeline_range": {
                    "start": self.df['timestamp'].min().isoformat(),
                    "end": self.df['timestamp'].max().isoformat()
                },
                "generated_at": datetime.now().isoformat()
            }

            metrics_dir = os.path.join(os.path.dirname(__file__), "metrics")
            os.makedirs(metrics_dir, exist_ok=True)
            metrics_file = os.path.join(metrics_dir, "macromaster_timeline_metrics.json")

            with open(metrics_file, 'w') as f:
                json.dump(metrics, f, indent=2)

            print(f"Timeline metrics saved: {metrics_file}")

        except Exception as e:
            print(f"Error saving timeline metrics: {e}")

def main():
    parser = argparse.ArgumentParser(description='MacroMaster Timeline Slider Dashboard')
    parser.add_argument('csv_path', help='Path to the MacroMaster CSV data file')

    args = parser.parse_args()

    if not os.path.exists(args.csv_path):
        print(f"Error: MacroMaster CSV file not found: {args.csv_path}")
        return

    # Create timeline slider dashboard
    timeline = MacroMasterTimelineSlider(args.csv_path)
    timeline.create_timeline_slider_dashboard()

if __name__ == "__main__":
    main()